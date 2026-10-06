<script setup lang="ts">
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { Message } from "@arco-design/web-vue";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { api } from "../api/console";
import { can } from "../state/session";
import { useResource } from "../composables/useResource";
import type { Query } from "../api/types";
const route = useRoute(),
  id = String(route.params.id);
const { data, loading, error, refresh } = useResource(() => api.pushDetail(id));
const table = ref<{ refresh: () => Promise<void> }>(),
  busy = ref(false);
const ready = computed(
  () =>
    data.value?.providers.length &&
    data.value.providers.every((p) => p.configured),
);
const count = computed(
  () => data.value?.providers.reduce((n, p) => n + p.devices, 0) ?? 0,
);
const columns: TableColumnData[] = [
  { title: "任务 ID", dataIndex: "id", width: 240 },
  { title: "平台", dataIndex: "platform" },
  { title: "Provider", dataIndex: "provider" },
  { title: "状态", dataIndex: "status" },
  { title: "重试次数", dataIndex: "attempts" },
  { title: "发送时间", slotName: "sent" },
];
const load = (query: Query) => api.pushJobs(id, query);
void refresh();
async function mutate(action: "publish" | "stop") {
  busy.value = true;
  try {
    if (action === "publish") await api.publishPush(id);
    else await api.stopPush(id);
    Message.success(
      action === "publish" ? "已入队，等待 Worker 投递" : "未投递任务已停止",
    );
    await refresh();
    await table.value?.refresh();
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "操作失败");
  } finally {
    busy.value = false;
  }
}
</script>
<template>
  <page-header
    title="推送任务详情"
    description="入队表示等待发送，成功与失败以设备投递回执为准。"
    ><router-link to="/push">返回推送列表</router-link
    ><a-button @click="refresh">刷新</a-button></page-header
  >
  <a-alert v-if="error" type="error">{{ error }}</a-alert
  ><a-spin :loading="loading" class="block"
    ><section v-if="data" class="surface detail-panel">
      <a-descriptions :column="{ xs: 1, sm: 2 }" bordered
        ><a-descriptions-item label="目标用户">{{
          data.campaign.userId
        }}</a-descriptions-item
        ><a-descriptions-item label="状态">{{
          { draft: "草稿", queued: "已入队", stopped: "已停止" }[
            data.campaign.state
          ]
        }}</a-descriptions-item
        ><a-descriptions-item label="推送标题" :span="2">{{
          data.campaign.title
        }}</a-descriptions-item
        ><a-descriptions-item label="推送正文" :span="2">{{
          data.campaign.body
        }}</a-descriptions-item
        ><a-descriptions-item label="打开页面">{{
          data.campaign.route ?? "默认页面"
        }}</a-descriptions-item
        ><a-descriptions-item label="已注册设备">{{
          count
        }}</a-descriptions-item></a-descriptions
      >
      <p v-for="p in data.providers" :key="p.provider">
        {{ p.provider }} · {{ p.devices }} 台设备 ·
        {{ p.configured ? "服务端已配置" : "服务端未配置" }}
      </p>
      <a-alert v-if="!count" class="notice"
        >目标用户尚未注册推送设备，草稿可保留。</a-alert
      ><a-alert v-else-if="!ready" type="warning" class="notice"
        >发布前需在服务端配置目标设备的 Provider。</a-alert
      >
      <a-space v-if="can('operations:push:publish')" class="notice"
        ><a-popconfirm
          v-if="data.campaign.state === 'draft'"
          :content="'确认向该用户的 ' + count + ' 台设备发送以上内容？'"
          @ok="mutate('publish')"
          ><a-button type="primary" :disabled="!ready" :loading="busy"
            >发布推送</a-button
          ></a-popconfirm
        ><a-popconfirm
          v-if="data.campaign.state !== 'stopped'"
          content="停止尚未投递的任务；已发送消息无法撤回。"
          @ok="mutate('stop')"
          ><a-button :loading="busy">停止任务</a-button></a-popconfirm
        ></a-space
      >
      <a-space
        ><a-tag v-for="d in data.delivery" :key="d.status"
          >{{ d.status }}：{{ d.count }}</a-tag
        ></a-space
      >
    </section></a-spin
  >
  <page-header
    title="设备投递记录"
    description="仅显示状态与重试次数，不返回推送 token 或供应商原始错误。"
  /><gi-table ref="table" :columns="columns" :load="load"
    ><template #sent="{ record }">{{
      record.sentAt
        ? new Date(record.sentAt * 1000).toLocaleString("zh-CN")
        : "尚未发送"
    }}</template></gi-table
  >
</template>
<style scoped>
.detail-panel {
  padding: 24px;
}
</style>
