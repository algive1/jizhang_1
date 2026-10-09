import type { Page } from "@playwright/test";
export async function navigateMenu(page: Page, group: string, title: string) {
  const heading = page.getByRole("button", { name: group, exact: true });
  if ((await heading.getAttribute("aria-expanded")) !== "true")
    await heading.click();
  await page.getByRole("link", { name: title, exact: true }).click();
}
