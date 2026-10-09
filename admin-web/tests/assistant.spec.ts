import { test, expect } from "@playwright/test";
import { navigateMenu } from "./navigation";
test("两级菜单、助手策略保存、提示词查看与手机布局", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(() =>
    sessionStorage.setItem(
      "haohao-console-session",
      "browser-commerce-test-session",
    ),
  );
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/");
  const heading = page.getByRole("button", { name: "AI 中心", exact: true });
  await expect(heading).toHaveAttribute("aria-expanded", "false");
  await expect(
    page.getByRole("link", { name: "助手策略", exact: true }),
  ).toBeHidden();
  await navigateMenu(page, "AI 中心", "助手策略");
  await expect(
    page.getByRole("heading", { name: "助手策略", exact: true }),
  ).toBeVisible();
  await page.getByLabel("每条文字最多字数", { exact: true }).fill("450");
  await page.getByRole("button", { name: "保存策略", exact: true }).click();
  await expect(page.getByText("助手策略已保存", { exact: true })).toBeVisible();
  await page.reload();
  await expect(
    page.getByLabel("每条文字最多字数", { exact: true }),
  ).toHaveValue("450");
  await expect(heading).toHaveAttribute("aria-expanded", "true");
  await page.screenshot({
    path: "../docs/qa/assistant-admin-2026-10-07/desktop.png",
    fullPage: true,
  });
  await page
    .getByRole("link", { name: "管理场景提示词与发布版本", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "提示词管理", exact: true }),
  ).toBeVisible();
  await page.goto("/assistant-policy");
  await page.setViewportSize({ width: 390, height: 844 });
  const breadcrumb = await page.locator(".breadcrumb-current").boundingBox();
  const controls = await page
    .locator(".topbar > .arco-space:last-child")
    .boundingBox();
  expect(breadcrumb!.x + breadcrumb!.width).toBeLessThanOrEqual(controls!.x);
  await page.screenshot({
    path: "../docs/qa/assistant-admin-2026-10-07/mobile.png",
    fullPage: true,
  });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth,
    ),
  ).toBe(false);
  await page.getByRole("button", { name: "展开菜单", exact: true }).click();
  await expect(
    page.getByRole("link", { name: "助手策略", exact: true }),
  ).toBeVisible();
  await heading.click();
  await expect(
    page.getByRole("link", { name: "助手策略", exact: true }),
  ).toBeHidden();
  expect(errors).toEqual([]);
});
