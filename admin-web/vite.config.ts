import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";
export default defineConfig(({ mode }) => ({
  plugins: [vue()],
  optimizeDeps: {
    include: [
      "echarts/core",
      "echarts/charts",
      "echarts/components",
      "echarts/renderers",
    ],
  },
  server: {
    port: 5173,
    proxy: {
      "/api":
        (loadEnv(mode, process.cwd(), "ADMIN_").ADMIN_LOCAL_API_TARGET ||
          loadEnv(mode, process.cwd(), "ADMIN_").ADMIN_API_TARGET) ??
        "http://127.0.0.1:8787",
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: { arco: ["@arco-design/web-vue"], charts: ["echarts"] },
      },
    },
  },
}));
