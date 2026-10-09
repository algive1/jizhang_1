import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { AssistantModelUnavailable, type AssistantModelProvider } from "../src/assistant_ai.js";
import { assistantQueryFeature } from "../src/assistant_boundary.js";
import { interpretationResponse } from "../src/assistant_analysis.js";

const facts = {
  startDate: "2026-09-08", endDate: "2026-10-07", currency: "CNY",
  totalExpense: 80.1, expenseCount: 2, previousExpense: null,
  categories: [{ name: "餐饮", amount: 80.1, count: 2 }], budget: null,
  observations: ["前一周期缺少记录，比较依据有限。"], suggestions: ["检查餐饮分类明细。"],
};
test("解读不能用中文金额绕过数字校验", () => {
  assert.equal(interpretationResponse.safeParse({ analysis: "消费了五百元。", suggestions: ["检查消费明细。"] }).success, false);
  assert.equal(interpretationResponse.safeParse({ analysis: "预算已调整。", suggestions: ["查看预算。"] }).success, false);
});
async function setup(t: { after: (fn: () => Promise<unknown>) => void }, provider: AssistantModelProvider) {
  const { app, store } = await createApp(":memory:", provider);
  t.after(() => app.close());
  const registered = await app.inject({ method: "POST", url: "/api/v1/auth/register",
    payload: { username: "spending_test", password: "local-test-password" } });
  const token = registered.json().token as string;
  const post = async (path: string, payload: unknown, authenticated = true) => {
    const response = await app.inject({ method: "POST", url: `/api/v1/assistant/${path}`,
      headers: authenticated ? { authorization: `Bearer ${token}` } : {}, payload: payload as object });
    return { status: response.statusCode, data: response.json() };
  };
  return { store, post };
}

test("消费分析意图覆盖自然语言并保持记账区分", () => {
  for (const text of ["帮我看看最近的消费情况给出合理建议", "最近一个月消费了多少", "近30天消费多少", "本月餐饮消费多少"]) {
    assert.equal(assistantQueryFeature(text), "summary", text);
  }
  assert.equal(assistantQueryFeature("午餐12元微信"), undefined);
});

test("解析与解读复用一次授权，摘要不向模型发送原始流水，重试幂等", async t => {
  const calls: Array<{ systemPrompt: string; userText: string }> = [];
  const { store, post } = await setup(t, { async complete(input) {
    calls.push(input);
    return input.systemPrompt.includes("查询条件解析器") ? JSON.stringify({
      startDate: "2026-09-08", endDate: "2026-10-07", currency: "CNY", categoryId: "food", advice: true,
    }) : JSON.stringify({ analysis: "已有消费以餐饮为主，比较依据有限。", suggestions: ["先检查餐饮明细，再设置合适预算。"] });
  } });
  const base = { requestId: "spending-query-request-0001", text: "分析最近的餐饮消费并给建议" };
  const authorized = await post("authorize", base);
  assert.equal(authorized.data.allowed, true);
  const planBody = { ...base, referenceDate: "2026-10-07", categories: [{ id: "food", name: "餐饮" }] };
  const plan = await post("query-plan", planBody);
  assert.equal(plan.status, 200);
  assert.equal(plan.data.plan.categoryId, "food");
  const interpret = await post("interpret", { ...base, facts });
  assert.equal(interpret.status, 200);
  assert.match(interpret.data.message, /比较依据有限/);
  assert.equal(calls.length, 2);
  assert.deepEqual(JSON.parse(calls[1]!.userText).facts, facts);
  assert.equal(JSON.parse(calls[1]!.userText).transactions, undefined);
  assert.deepEqual((await post("interpret", { ...base, facts })).data, interpret.data);
  assert.deepEqual((await post("query-plan", planBody)).data, plan.data);
  assert.equal(calls.length, 2);
  const usage = store.db.prepare("SELECT used FROM assistant_usage").get() as { used: number };
  assert.equal(usage.used, 1);
  assert.equal((await post("interpret", { ...base, facts: { ...facts, totalExpense: 200 } })).status, 409);
});

test("无权限与不合法请求不会调用模型，模型不能新增数字或执行操作", async t => {
  let output = JSON.stringify({ analysis: "消费是999元。", suggestions: ["设置预算。"] });
  let calls = 0;
  const { post, store } = await setup(t, { async complete() { calls++; return output; } });
  const body = { requestId: "spending-invalid-request-0001", text: "分析最近消费并给建议", facts };
  assert.equal((await post("interpret", body, false)).status, 401);
  assert.equal((await post("interpret", { ...body, facts: { ...facts, totalExpense: -1 } })).status, 400);
  assert.equal(calls, 0);
  assert.equal((await post("interpret", body)).status, 502);
  assert.equal((store.db.prepare("SELECT used FROM assistant_usage").get() as { used: number }).used, 0);
  output = JSON.stringify({ analysis: "已为你设置预算。", suggestions: ["留意消费。"] });
  assert.equal((await post("interpret", { ...body, requestId: "spending-invalid-request-0002" })).status, 502);
  const policy = JSON.parse((store.db.prepare("SELECT data_json FROM assistant_policy").get() as { data_json: string }).data_json);
  store.db.prepare("UPDATE assistant_policy SET data_json=?").run(JSON.stringify({ ...policy, enabled: false }));
  assert.equal((await post("interpret", { ...body, requestId: "spending-disabled-request-0001" })).data.allowed, false);
  assert.equal(calls, 2);
});

test("查询条件校验分类、真实日期、未来范围与模糊问题，服务不可用退还额度", async t => {
  let output: unknown = { startDate: "2026-09-08", endDate: "2026-10-07", currency: "CNY", categoryId: "other", advice: false };
  let unavailable = false;
  const { post, store } = await setup(t, { async complete() {
    if (unavailable) throw new AssistantModelUnavailable("test outage");
    return JSON.stringify(output);
  } });
  const body = { requestId: "spending-plan-request-0001", text: "9月消费多少", referenceDate: "2026-10-07", categories: [{ id: "food", name: "餐饮" }] };
  assert.equal((await post("query-plan", body)).status, 502);
  output = { ...(output as object), categoryId: null, startDate: "2026-02-30" };
  assert.equal((await post("query-plan", { ...body, requestId: "spending-plan-request-0002" })).status, 502);
  output = { startDate: "2026-10-01", endDate: "2026-10-08", currency: "CNY", categoryId: null, advice: false };
  assert.equal((await post("query-plan", { ...body, requestId: "spending-plan-request-0003" })).status, 502);
  output = { clarification: "你想查看哪一年的九月消费？" };
  assert.match((await post("query-plan", { ...body, requestId: "spending-plan-request-0004" })).data.message, /哪一年/);
  unavailable = true;
  assert.equal((await post("query-plan", { ...body, requestId: "spending-plan-request-0005" })).status, 503);
  assert.equal((store.db.prepare("SELECT used FROM assistant_usage").get() as { used: number }).used, 1);
});
