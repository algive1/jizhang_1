import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
export default defineConfig({plugins:[vue()],optimizeDeps:{include:['echarts/core','echarts/charts','echarts/components','echarts/renderers']},server:{port:5173,proxy:{'/api':process.env.ADMIN_API_TARGET ?? 'http://127.0.0.1:8787'}},build:{rollupOptions:{output:{manualChunks:{arco:['@arco-design/web-vue'],charts:['echarts']}}}}});
