<script setup lang="ts">
import { reactive, ref } from "vue";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import IntegrationEditor from "../components/IntegrationEditor.vue";
import GiTable from "../components/GiTable.vue";
import { request } from "../api/client";
import type { Page, Query } from "../api/types";
import { can } from "../state/session";
const policy = reactive({ enabled: false, dailyLimit: 30, maxSeconds: 60 }),
  error = ref(""),
  busy = ref(false);
request<typeof policy>("/asr/policy")
  .then((v) => Object.assign(policy, v))
  .catch((e) => {
    error.value = String(e);
  });
async function save() {
  busy.value = true;
  try {
    await request("/asr/policy", { method: "PUT", body: policy });
    Message.success("语音识别策略已保存");
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
const usage = (query: Query) =>
  request<Page<Record<string, unknown>>>("/asr/usage", { query });
const columns = [
  { title: "用户", dataIndex: "userId" },
  { title: "状态", dataIndex: "status" },
  { title: "音频时长 ms", dataIndex: "durationMs" },
  { title: "耗时 ms", dataIndex: "latencyMs" },
  { title: "腾讯请求 ID", dataIndex: "providerRequestId" },
  { title: "时间戳", dataIndex: "createdAt" },
];
</script>
<template>
  <page-header
    title="腾讯一句话语音识别"
    description="支持最长 60 秒的云端识别，APP 由用户主动选择后上传。调用记录不保存录音或识别文本。"
  /><a-alert v-if="error" type="error">{{ error }}</a-alert>
  <section class="surface detail-section">
    <a-form :model="policy" layout="inline" :disabled="!can('ai:model:edit')"
      ><a-form-item label="启用"
        ><a-switch v-model="policy.enabled" /></a-form-item
      ><a-form-item label="每用户每日次数"
        ><a-input-number
          v-model="policy.dailyLimit"
          :min="1"
          :max="1000" /></a-form-item
      ><a-form-item label="最长秒数"
        ><a-input-number
          v-model="policy.maxSeconds"
          :min="1"
          :max="60" /></a-form-item
      ><a-button
        v-if="can('ai:model:edit')"
        type="primary"
        :loading="busy"
        @click="save"
        >保存策略</a-button
      ></a-form
    >
  </section>
  <integration-editor provider="asr" /><gi-table
    v-if="can('ai:usage:view')"
    :columns="columns"
    :load="usage"
  />
</template>
