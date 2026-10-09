import { test, expect } from "@playwright/test";
import { navigateMenu } from "./navigation";
test("会员草稿、支付渠道、腾讯 ASR 与后端维护页面对接实际服务", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  // Login and its production rate limit are exercised by console.spec.ts.
  await page.addInitScript(() =>
    sessionStorage.setItem(
      "haohao-console-session",
      "browser-commerce-test-session",
    ),
  );
  await page.goto("/");
  await navigateMenu(page, "会员与支付", "套餐与权益");
  await expect(
    page.getByRole("heading", { name: "套餐与权益", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("Error: DataCloneError")).toHaveCount(0);
  await page.getByPlaceholder("本次修改说明（保存必填）").fill("浏览器验收");
  await page.getByRole("button", { name: "保存草稿", exact: true }).click();
  await expect(
    page.getByText("草稿已保存，发布后 APP 生效", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "发布最新草稿", exact: true }).click();
  await page.getByRole("button", { name: "确定", exact: true }).click();
  await expect(page.getByText("套餐已发布", { exact: true })).toBeVisible();
  await page.getByRole("link", { name: "支付渠道", exact: true }).click();
  await expect(page.getByText("微信 AppID", { exact: true })).toBeVisible();
  await page.getByText("支付宝", { exact: true }).click();
  await expect(page.getByText("支付宝 AppID", { exact: true })).toBeVisible();
  await page.getByRole("link", { name: "订单与退款", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "订单与退款", exact: true }),
  ).toBeVisible();
  await navigateMenu(page, "AI 中心", "腾讯语音识别");
  await expect(
    page.getByRole("heading", { name: "腾讯一句话语音识别", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("腾讯 SecretId", { exact: true })).toBeVisible();
  await navigateMenu(page, "系统管理", "后端更新与备份");
  await expect(
    page.getByRole("heading", { name: "后端更新与备份", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("待配置", { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});
