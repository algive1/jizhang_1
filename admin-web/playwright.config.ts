import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests",
  testMatch: "*.spec.ts",
  workers: 1,
  use: { baseURL: "http://127.0.0.1:5178", headless: true },
  webServer: [
    {
      command:
        "node --import ../server/node_modules/tsx/dist/loader.mjs tests/server.ts",
      url: "http://127.0.0.1:8790/api/v1/app/update?platform=android&version=1.0.0",
      reuseExistingServer: false,
    },
    {
      command: "npm run dev -- --port 5178 --strictPort",
      url: "http://127.0.0.1:5178",
      env: {
        ADMIN_API_TARGET: "http://127.0.0.1:8790",
        ADMIN_LOCAL_API_TARGET: "http://127.0.0.1:8790",
      },
      reuseExistingServer: false,
    },
  ],
});
