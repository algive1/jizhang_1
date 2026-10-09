import { test, expect } from "@playwright/test";
import { navigateMenu } from "./navigation";
test("P0 login, dashboard, user detail, versions and responsive layout", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await expect(page).toHaveURL(/login/);
  await page.getByLabel("管理员账号", { exact: true }).fill("browser_admin");
  await page
    .getByLabel("密码", { exact: true })
    .fill("browser-test-password-2026");
  await page.getByRole("button", { name: "登录", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "工作台", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("尚未收到设备版本上报")).toBeVisible();
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.screenshot({
    path: "test-results/p0-dashboard-desktop.png",
    fullPage: true,
  });
  await navigateMenu(page, "用户中心", "用户管理");
  await expect(
    page.getByRole("link", { name: "浏览器测试用户", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "浏览器测试用户", exact: true }).click();
  await expect(page.getByRole("heading", { name: "用户详情" })).toBeVisible();
  await navigateMenu(page, "APP 管理", "版本与灰度发布");
  await page.getByRole("button", { name: "新建版本", exact: true }).click();
  await page.getByLabel("versionName", { exact: true }).fill("3.0.0");
  await page.getByLabel("versionCode", { exact: true }).fill("300");
  await page.getByLabel("最低支持版本", { exact: true }).fill("1.0.0");
  await page
    .getByLabel("下载地址（HTTPS）", { exact: true })
    .fill("https://example.com/browser-test.apk");
  await page
    .getByLabel("更新日志", { exact: true })
    .fill("浏览器自动化测试版本");
  await page.getByRole("button", { name: "保存草稿" }).click();
  await expect(
    page.getByRole("cell", { name: "3.0.0", exact: true }),
  ).toBeVisible();
  await page
    .getByRole("row")
    .filter({ has: page.getByRole("cell", { name: "3.0.0", exact: true }) })
    .getByRole("link", { name: "详情" })
    .click();
  await expect(
    page.getByRole("heading", { name: "APP 版本详情" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "编辑草稿" }).click();
  await page.getByLabel("更新日志", { exact: true }).fill("已在详情页修订");
  await page.getByRole("button", { name: "保存草稿" }).click();
  await expect(page.getByText("已在详情页修订", { exact: true })).toBeVisible();
  await page.getByRole("link", { name: "远程配置", exact: true }).click();
  await page.getByRole("button", { name: "新建修订" }).click();
  await page.getByLabel("标识", { exact: true }).fill("browser.features");
  await page.getByLabel("修改备注", { exact: true }).fill("浏览器测试");
  await page.getByRole("button", { name: "保存新修订" }).click();
  await expect(
    page.getByRole("cell", { name: "browser.features", exact: true }),
  ).toBeVisible();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({
    path: "test-results/p0-config-mobile.png",
    fullPage: true,
  });
  await expect(page.getByRole("button", { name: "展开菜单" })).toBeVisible();
  await page.getByRole("button", { name: "展开菜单" }).click();
  await expect(
    page.getByRole("link", { name: "用户管理", exact: true }),
  ).toBeVisible();
  expect(errors).toEqual([]);
});
test("support role sees only granted menus and direct API refuses publishing", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("管理员账号", { exact: true }).fill("browser_support");
  await page
    .getByLabel("密码", { exact: true })
    .fill("browser-test-password-2026");
  await page.getByRole("button", { name: "登录", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "用户管理", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("link", { name: "版本与灰度发布", exact: true }),
  ).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "禁用", exact: true }),
  ).toHaveCount(0);
  const status = await page.evaluate(async () => {
    const token = sessionStorage.getItem("haohao-console-session");
    return (
      await fetch("/api/v1/console/releases", {
        headers: { Authorization: `Bearer ${token}` },
      })
    ).status;
  });
  expect(status).toBe(403);
});
test("P1 failure trace and versioned rule editing use real APIs", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("管理员账号", { exact: true }).fill("browser_admin");
  await page
    .getByLabel("密码", { exact: true })
    .fill("browser-test-password-2026");
  await page.getByRole("button", { name: "登录", exact: true }).click();
  await navigateMenu(page, "记账管理", "失败案例");
  await expect(
    page.getByRole("cell", { name: "database_write_failed", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "时间轴", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "自动记账事件时间轴" }),
  ).toBeVisible();
  await expect(
    page.getByRole("list").getByText("通知与页面匹配", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("database_write_failed", { exact: true }),
  ).toBeVisible();
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.screenshot({
    path: "test-results/p1-timeline-desktop.png",
    fullPage: true,
  });
  await page.getByRole("link", { name: "识别与适配规则", exact: true }).click();
  await page.getByRole("button", { name: "新建修订" }).click();
  await page.getByLabel("标识", { exact: true }).fill("browser.rule");
  await page.getByLabel("修改备注", { exact: true }).fill("事件规则测试");
  await page.getByLabel("配置内容", { exact: true }).fill(
    JSON.stringify({
      packageName: "com.test.payment",
      pageIdentifier: "success",
      activity: "",
      nodeFeatures: [],
      textFeatures: ["支付成功"],
      notificationTitlePattern: "",
      notificationBodyPattern: "",
      amountPattern: "[0-9]+",
      merchantPattern: "",
      priority: 100,
      minAppVersion: "1.0.0",
      maxAppVersion: null,
      enabled: true,
    }),
  );
  await page.getByRole("button", { name: "保存新修订" }).click();
  await expect(
    page.getByRole("cell", { name: "browser.rule", exact: true }),
  ).toBeVisible();
});
test("P2 model configuration persists and AI metrics show unknown usage honestly", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("管理员账号", { exact: true }).fill("browser_admin");
  await page
    .getByLabel("密码", { exact: true })
    .fill("browser-test-password-2026");
  await page.getByRole("button", { name: "登录", exact: true }).click();
  await navigateMenu(page, "AI 中心", "模型管理");
  await page.getByRole("button", { name: "新增模型", exact: true }).click();
  await page.getByLabel("name", { exact: true }).fill("浏览器测试模型");
  await page.getByLabel("model", { exact: true }).fill("test-model");
  await page
    .getByLabel("endpoint", { exact: true })
    .fill("https://models.example.test");
  await page.getByLabel("keyRef", { exact: true }).fill("BROWSER_TEST_AI_KEY");
  await page.getByRole("button", { name: "保存模型", exact: true }).click();
  await expect(
    page.getByRole("cell", { name: "浏览器测试模型", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("密钥未配置 · Endpoint 未允许")).toBeVisible();
  await page.getByRole("link", { name: "用量与成本", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "AI 用量与成本" }),
  ).toBeVisible();
  await expect(page.getByText("0 / 1 次可估价")).toBeVisible();
  await page
    .getByRole("row")
    .filter({
      has: page.getByRole("cell", { name: "browser-ai-call", exact: true }),
    })
    .getByRole("link", { name: "详情" })
    .click();
  await expect(
    page.getByRole("heading", { name: "AI 调用详情" }),
  ).toBeVisible();
  await expect(page.getByText("未知", { exact: true })).toHaveCount(3);
});
test("system sessions and Push drafts provide real management workflows", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("管理员账号", { exact: true }).fill("browser_admin");
  await page
    .getByLabel("密码", { exact: true })
    .fill("browser-test-password-2026");
  await page.getByRole("button", { name: "登录", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "工作台", exact: true }),
  ).toBeVisible();
  const other = await page.evaluate(async () => {
    const token = (
      await (
        await fetch("/api/v1/console/auth/login", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            username: "browser_admin",
            password: "browser-test-password-2026",
          }),
        })
      ).json()
    ).data.token as string;
    const sessions = (
      await (
        await fetch("/api/v1/console/sessions", {
          headers: { Authorization: `Bearer ${token}` },
        })
      ).json()
    ).data.items as Array<{ id: string; current: boolean }>;
    return { token, id: sessions.find((s) => s.current)!.id };
  });
  await navigateMenu(page, "系统管理", "在线会话");
  await expect(page.getByText("当前会话", { exact: true })).toBeVisible();
  const lastRow = page
    .getByRole("row")
    .filter({ has: page.getByRole("cell", { name: other.id, exact: true }) });
  await lastRow.getByRole("button", { name: "撤销" }).click();
  await page.getByRole("button", { name: "确定", exact: true }).click();
  await expect(page.getByText("会话已撤销", { exact: true })).toBeVisible();
  expect(
    await page.evaluate(
      async (token) =>
        (
          await fetch("/api/v1/console/auth/me", {
            headers: { Authorization: `Bearer ${token}` },
          })
        ).status,
      other.token,
    ),
  ).toBe(401);
  await page.getByRole("link", { name: "登录日志", exact: true }).click();
  await expect(page.getByRole("heading", { name: "登录日志" })).toBeVisible();
  const userId = await page.evaluate(async () => {
    const token = sessionStorage.getItem("haohao-console-session");
    return (
      await (
        await fetch("/api/v1/console/users?q=browser_user", {
          headers: { Authorization: `Bearer ${token}` },
        })
      ).json()
    ).data.items[0].id as string;
  });
  await navigateMenu(page, "运营中心", "Push 推送");
  await page.getByRole("button", { name: "新建推送草稿" }).click();
  await page.getByLabel("目标用户 ID").fill(userId);
  await page.getByLabel("推送标题").fill("浏览器推送草稿");
  await page.getByLabel("推送正文").fill("仅测试草稿，不发送消息");
  await page.getByRole("button", { name: "保存推送草稿" }).click();
  await expect(
    page.getByRole("heading", { name: "推送任务详情" }),
  ).toBeVisible();
  await expect(
    page.getByText("目标用户尚未注册推送设备，草稿可保留。"),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "发布推送", exact: true }),
  ).toBeDisabled();
});
test("P3 FAQ persistence, feedback processing and backup privacy states", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("管理员账号", { exact: true }).fill("browser_admin");
  await page
    .getByLabel("密码", { exact: true })
    .fill("browser-test-password-2026");
  await page.getByRole("button", { name: "登录", exact: true }).click();
  await navigateMenu(page, "运营中心", "公告与 FAQ");
  await page.getByRole("button", { name: "新增内容" }).click();
  await page.getByLabel("运营标题").fill("浏览器 FAQ");
  await page.getByLabel("运营正文").fill("离线仍可以手动记账");
  await page.getByRole("button", { name: "保存内容" }).click();
  await expect(
    page.getByRole("cell", { name: "浏览器 FAQ", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "用户反馈", exact: true }).click();
  await expect(
    page.getByRole("cell", { name: "浏览器测试反馈", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "详情", exact: true }).click();
  await expect(page.getByRole("heading", { name: "反馈详情" })).toBeVisible();
  await expect(
    page.getByText("自动记账遇到问题，联系方式 [号码已脱敏]", { exact: true }),
  ).toBeVisible();
  await expect(page.getByText("13800138000", { exact: true })).toHaveCount(0);
  await navigateMenu(page, "数据安全", "云备份");
  await expect(
    page.getByRole("heading", { name: "云备份", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText(
      "现有备份为 gzip 压缩，尚未端到端加密。加密协议、任务遥测和恢复记录待 APP 接入。",
    ),
  ).toBeVisible();
});
test("batch user management and password workflows invalidate sessions correctly", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("管理员账号", { exact: true }).fill("browser_admin");
  await page
    .getByLabel("密码", { exact: true })
    .fill("browser-test-password-2026");
  await page.getByRole("button", { name: "登录", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "工作台", exact: true }),
  ).toBeVisible();
  await navigateMenu(page, "用户中心", "用户管理");
  const row = page.getByRole("row").filter({
    has: page.getByRole("link", { name: "浏览器测试用户", exact: true }),
  });
  await row.getByRole("checkbox").locator("..").click();
  await page.getByRole("button", { name: "批量禁用", exact: true }).click();
  await page.getByRole("button", { name: "确定", exact: true }).click();
  await expect(row.getByText("已禁用", { exact: true })).toBeVisible();
  await row.getByRole("checkbox").locator("..").click();
  await page.getByRole("button", { name: "批量解禁", exact: true }).click();
  await page.getByRole("button", { name: "确定", exact: true }).click();
  await expect(row.getByText("正常", { exact: true })).toBeVisible();
  await navigateMenu(page, "系统管理", "管理员");
  await page.getByRole("button", { name: "新增管理员", exact: true }).click();
  await page.getByLabel("管理员账号名称").fill("browser_managed");
  await page.getByLabel("管理员初始密码").fill("browser-managed-password");
  await page.getByRole("button", { name: "创建", exact: true }).click();
  const admin = page.getByRole("row").filter({
    has: page.getByRole("cell", { name: "browser_managed", exact: true }),
  });
  await admin.getByRole("button", { name: "重置密码", exact: true }).click();
  await page
    .getByLabel("新密码（至少 12 位）")
    .fill("browser-managed-reset-password");
  await page.getByLabel("确认新密码").fill("browser-managed-reset-password");
  await page.getByRole("button", { name: "保存密码", exact: true }).click();
  await expect(
    page.getByText("密码已重置，旧会话已撤销", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "修改我的密码", exact: true }).click();
  await page.getByLabel("当前密码").fill("browser-test-password-2026");
  await page
    .getByLabel("新密码（至少 12 位）")
    .fill("browser-admin-changed-password");
  await page.getByLabel("确认新密码").fill("browser-admin-changed-password");
  await page.getByRole("button", { name: "保存密码", exact: true }).click();
  await expect(page).toHaveURL(/login/);
  expect(
    await page.evaluate(() => sessionStorage.getItem("haohao-console-session")),
  ).toBeNull();
});
