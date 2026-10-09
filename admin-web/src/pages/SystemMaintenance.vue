<script setup lang="ts">
import { reactive, ref } from "vue";
import { Message, Modal } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { request } from "../api/client";
import type { Page, Query } from "../api/types";
import { can } from "../state/session";
interface Status {
  version: string;
  image: string | null;
  databaseVersion: number;
  uptimeSeconds: number;
  testingFreeAccess: boolean;
  deploymentConfigured: boolean;
  imageRepository: string;
  latestBackup: { filename: string; createdAt: number } | null;
}
interface Job {
  id: string;
  version: string;
  image: string;
  action: string;
  reason: string;
  status: string;
  message: string;
  backupId: string | null;
}
const status = ref<Status>(),
  error = ref(""),
  busy = ref(false),
  editing = ref(false),
  table = ref<{ refresh: () => Promise<void> }>();
const form = reactive({ version: "", image: "", action: "update", reason: "" });
async function refresh() {
  try {
    status.value = await request<Status>("/system/status");
    error.value = "";
    await table.value?.refresh();
  } catch (e) {
    error.value = String(e);
  }
}
void refresh();
async function backup() {
  busy.value = true;
  try {
    await request("/system/backups", { method: "POST" });
    Message.success("备份完成并通过完整性校验");
    await refresh();
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
async function save() {
  busy.value = true;
  try {
    await request("/system/updates", { method: "POST", body: form });
    editing.value = false;
    Message.success("更新任务草稿已保存");
    await refresh();
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
function dispatch(job: Job) {
  Modal.confirm({
    title: job.action === "rollback" ? "执行后端回滚" : "执行后端更新",
    content: `将向部署服务提交 ${job.version}，镜像 ${job.image}。必须已有一小时内的完整备份。部署服务负责迁移、健康检查和失败恢复。`,
    onOk: async () => {
      try {
        await request(`/system/updates/${job.id}/dispatch`, {
          method: "POST",
          body: { confirmed: true },
        });
        Message.success("部署服务已接收，刷新查看回执");
        await refresh();
      } catch (e) {
        error.value = String(e);
      }
    },
  });
}
const load = (query: Query) => request<Page<Job>>("/system/updates", { query });
const labels: Record<string, string> = {
  draft: "草稿",
  dispatching: "等待部署确认",
  accepted: "已接收",
  running: "执行中",
  succeeded: "成功",
  failed: "失败",
};
const columns = [
  { title: "目标版本", dataIndex: "version" },
  { title: "操作", slotName: "action" },
  { title: "镜像摘要", dataIndex: "image" },
  { title: "状态", slotName: "status" },
  { title: "执行结果", dataIndex: "message" },
  { title: "操作", slotName: "actions", width: 130 },
];
</script>
<template>
  <page-header
    title="后端更新与备份"
    description="使用固定镜像摘要创建更新任务，经受控部署服务执行并接收真实回执。"
    ><a-button @click="refresh">刷新状态</a-button></page-header
  ><a-alert v-if="error" type="error">{{ error }}</a-alert>
  <section v-if="status" class="surface detail-section">
    <a-descriptions :column="2" bordered
      ><a-descriptions-item label="当前版本">{{
        status.version
      }}</a-descriptions-item
      ><a-descriptions-item label="数据库版本">{{
        status.databaseVersion
      }}</a-descriptions-item
      ><a-descriptions-item label="测试免费开关">{{
        status.testingFreeAccess ? "已开启" : "已关闭"
      }}</a-descriptions-item
      ><a-descriptions-item label="部署服务">{{
        status.deploymentConfigured ? "已配置" : "待配置"
      }}</a-descriptions-item
      ><a-descriptions-item label="最近手动备份">{{
        status.latestBackup?.filename ?? "尚无记录"
      }}</a-descriptions-item
      ><a-descriptions-item label="运行时间"
        >{{ status.uptimeSeconds }} 秒</a-descriptions-item
      ></a-descriptions
    ><a-space style="margin-top: 16px"
      ><a-button v-if="can('system:backup')" :loading="busy" @click="backup"
        >立即备份并校验</a-button
      ><a-button
        v-if="can('system:update')"
        type="primary"
        @click="editing = true"
        >新建更新任务</a-button
      ></a-space
    ><a-alert v-if="!status.deploymentConfigured" style="margin-top: 16px"
      >正式部署服务尚未配置。当前可备份、查看版本及准备任务，执行结果由部署服务回传。</a-alert
    >
  </section>
  <gi-table ref="table" :columns="columns" :load="load"
    ><template #action="{ record }">{{
      record.action === "rollback" ? "回滚" : "更新"
    }}</template
    ><template #status="{ record }">{{
      labels[record.status] ?? record.status
    }}</template
    ><template #actions="{ record }"
      ><a-button
        v-if="
          can('system:update') &&
          ['draft', 'dispatching'].includes(record.status)
        "
        type="text"
        :disabled="!status?.deploymentConfigured"
        @click="dispatch(record)"
        >确认执行</a-button
      ></template
    ></gi-table
  ><a-modal
    v-model:visible="editing"
    title="创建后端更新草稿"
    :ok-loading="busy"
    @ok="save"
    ><a-form :model="form" layout="vertical"
      ><a-form-item label="操作"
        ><a-select v-model="form.action"
          ><a-option value="update">更新</a-option
          ><a-option value="rollback">回滚</a-option></a-select
        ></a-form-item
      ><a-form-item label="目标版本"
        ><a-input v-model="form.version" placeholder="1.0.1" /></a-form-item
      ><a-form-item label="固定镜像摘要"
        ><a-input
          v-model="form.image"
          :placeholder="`${status?.imageRepository || '部署配置指定仓库'}@sha256:...`" /></a-form-item
      ><a-form-item label="原因"
        ><a-textarea v-model="form.reason" /></a-form-item></a-form
  ></a-modal>
</template>
