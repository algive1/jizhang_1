<script setup lang="ts">
import { reactive, ref } from "vue";
import { useRouter } from "vue-router";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { api } from "../api/console";
import { can } from "../state/session";
import type { PushCampaign } from "../api/types";
const router = useRouter();
const editing = ref(false),
  saving = ref(false),
  error = ref("");
const form = reactive<
  Pick<PushCampaign, "userId" | "title" | "body"> & {
    route: Exclude<PushCampaign["route"], null>;
  }
>({ userId: "", title: "", body: "", route: "/profile/messages" });
const drawerWidth = Math.min(520, window.innerWidth * 0.9);
const columns: TableColumnData[] = [
  { title: "标题", dataIndex: "title" },
  { title: "目标用户", dataIndex: "userId", width: 240 },
  { title: "状态", slotName: "state" },
  { title: "入队设备", dataIndex: "deviceCount" },
  { title: "创建时间", slotName: "date", width: 180 },
  { title: "操作", slotName: "actions", fixed: "right", width: 90 },
];
async function save() {
  saving.value = true;
  error.value = "";
  try {
    const { id } = await api.createPush({ ...form });
    await router.push(`/push/${id}`);
  } catch (e) {
    error.value = e instanceof Error ? e.message : "保存失败";
  } finally {
    saving.value = false;
  }
}
</script>
<template>
  <page-header
    title="Push 推送"
    description="创建指定用户的推送草稿，预览后明确发布到现有设备队列。"
  />
  <gi-table :columns="columns" :load="api.pushCampaigns"
    ><template #toolbar
      ><a-button
        v-if="can('operations:push:edit')"
        type="primary"
        @click="editing = true"
        >新建推送草稿</a-button
      ></template
    ><template #state="{ record }">{{
      { draft: "草稿", queued: "已入队", stopped: "已停止" }[
        record.state as PushCampaign["state"]
      ]
    }}</template
    ><template #date="{ record }">{{
      new Date(record.createdAt * 1000).toLocaleString("zh-CN")
    }}</template
    ><template #actions="{ record }"
      ><router-link :to="'/push/' + record.id">详情</router-link></template
    ></gi-table
  >
  <a-drawer
    v-model:visible="editing"
    title="新建推送草稿"
    :width="drawerWidth"
    :footer="false"
    ><a-alert v-if="error" type="error">{{ error }}</a-alert
    ><a-form :model="form" layout="vertical" @submit-success="save">
      <a-form-item label="目标用户 ID" field="userId" required
        ><a-input
          v-model="form.userId"
          :input-attrs="{ 'aria-label': '目标用户 ID' }"
      /></a-form-item>
      <a-form-item label="推送标题" field="title" required
        ><a-input
          v-model="form.title"
          :max-length="80"
          :input-attrs="{ 'aria-label': '推送标题' }"
      /></a-form-item>
      <a-form-item label="推送正文" field="body" required
        ><a-textarea
          v-model="form.body"
          :max-length="500"
          :textarea-attrs="{ 'aria-label': '推送正文' }"
      /></a-form-item>
      <a-form-item label="点击后打开"
        ><a-select v-model="form.route"
          ><a-option value="/profile/messages">消息中心</a-option
          ><a-option value="/profile">个人中心</a-option
          ><a-option value="/">首页</a-option></a-select
        ></a-form-item
      >
      <a-button type="primary" html-type="submit" :loading="saving"
        >保存推送草稿</a-button
      >
    </a-form></a-drawer
  >
</template>
