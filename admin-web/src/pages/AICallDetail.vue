<script setup lang="ts">
import { useRoute } from "vue-router";
import PageHeader from "../components/PageHeader.vue";
import { api } from "../api/console";
import { useResource } from "../composables/useResource";
const route = useRoute();
const { data, loading, error, refresh } = useResource(() =>
  api.aiCall(String(route.params.id)),
);
void refresh();
</script>
<template>
  <page-header
    title="AI 调用详情"
    description="一次上游尝试的回执；备用模型会记录为另一次尝试。"
    ><router-link to="/ai-usage">返回用量与成本</router-link
    ><a-button @click="refresh">刷新</a-button></page-header
  >
  <a-alert v-if="error" type="error">{{ error }}</a-alert>
  <a-spin :loading="loading" class="block"
    ><section v-if="data" class="surface detail-panel">
      <a-descriptions :column="{ xs: 1, sm: 2 }" bordered>
        <a-descriptions-item label="调用 ID" :span="2">{{
          data.id
        }}</a-descriptions-item
        ><a-descriptions-item label="功能">{{
          data.feature
        }}</a-descriptions-item
        ><a-descriptions-item label="模型">{{
          data.model
        }}</a-descriptions-item>
        <a-descriptions-item label="上游结果">{{
          data.status === "success" ? "成功" : "失败"
        }}</a-descriptions-item
        ><a-descriptions-item label="耗时"
          >{{ data.durationMs }} ms</a-descriptions-item
        >
        <a-descriptions-item label="输入 Token">{{
          data.inputTokens ?? "未知"
        }}</a-descriptions-item
        ><a-descriptions-item label="输出 Token">{{
          data.outputTokens ?? "未知"
        }}</a-descriptions-item>
        <a-descriptions-item label="估算成本 USD">{{
          data.costMicroUsd == null
            ? "未知"
            : "$" + (data.costMicroUsd / 1000000).toFixed(6)
        }}</a-descriptions-item
        ><a-descriptions-item label="调用时间">{{
          new Date(data.createdAt * 1000).toLocaleString("zh-CN")
        }}</a-descriptions-item> </a-descriptions
      ><a-alert class="notice"
        >输入、输出与密钥不在日志中保存。失败详情与识别效果需供应商和 APP
        返回受控错误码后接入。</a-alert
      >
    </section></a-spin
  >
</template>
<style scoped>
.detail-panel {
  padding: 24px;
}
</style>
