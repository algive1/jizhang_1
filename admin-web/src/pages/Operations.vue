<script setup lang="ts">
import { ref, reactive } from "vue";
import { Message } from "@arco-design/web-vue";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { api } from "../api/console";
import { can } from "../state/session";
import type { Operation } from "../api/types";
const tab = ref("content"),
  table = ref<{ refresh: () => Promise<void> }>(),
  editing = ref(false),
  id = ref(""),
  error = ref(""),
  saving = ref(false);
const form = reactive<{
  kind: Operation["kind"];
  title: string;
  body: string;
  enabled: boolean;
}>({ kind: "faq", title: "", body: "", enabled: false });
const columns: TableColumnData[] = [
  { title: "标题", dataIndex: "title" },
  { title: "类型", dataIndex: "kind" },
  { title: "状态", slotName: "status" },
  { title: "操作", slotName: "actions" },
];
const announcementColumns: TableColumnData[] = [
  { title: "标题", dataIndex: "title" },
  { title: "正文", dataIndex: "body" },
  { title: "发布时间", slotName: "date" },
];
function edit(row?: Operation) {
  id.value = row?.id ?? "";
  Object.assign(
    form,
    row
      ? {
          kind: row.kind,
          title: row.title,
          body: row.body,
          enabled: Boolean(row.enabled),
        }
      : { kind: "faq", title: "", body: "", enabled: false },
  );
  editing.value = true;
  error.value = "";
}
async function save() {
  saving.value = true;
  error.value = "";
  try {
    if (tab.value === "announcements")
      await api.publishAnnouncement(form.title, form.body);
    else await api.saveOperation(id.value || undefined, { ...form });
    editing.value = false;
    Message.success("运营内容已保存");
    await table.value?.refresh();
  } catch (e) {
    error.value = e instanceof Error ? e.message : "保存失败";
  } finally {
    saving.value = false;
  }
}
</script>
<template>
  <page-header
    title="公告与 FAQ"
    description="公告复用 APP 消息中心；Banner / FAQ / 活动提供真实配置 API。"
  /><a-tabs v-model:active-key="tab" @change="editing = false"
    ><a-tab-pane key="content" title="FAQ / Banner / 活动" /><a-tab-pane
      key="announcements"
      title="APP 公告" /></a-tabs
  ><a-alert v-if="tab === 'content'" class="notice"
    >配置已持久化，公开读取接口已可用；APP 渲染接入为 TODO。</a-alert
  ><gi-table
    v-if="tab === 'content'"
    ref="table"
    key="content"
    :columns="columns"
    :load="api.operations"
    ><template #toolbar
      ><a-button v-if="can('operations:edit')" type="primary" @click="edit()"
        >新增内容</a-button
      ></template
    ><template #status="{ record }"
      ><a-tag :color="record.enabled ? 'green' : 'gray'">{{
        record.enabled ? "启用" : "停用"
      }}</a-tag></template
    ><template #actions="{ record }"
      ><a-button
        v-if="can('operations:edit')"
        type="text"
        size="small"
        @click="edit(record)"
        >编辑</a-button
      ></template
    ></gi-table
  ><gi-table
    v-else
    ref="table"
    key="announcements"
    :columns="announcementColumns"
    :load="api.announcements"
    ><template #toolbar
      ><a-button v-if="can('operations:publish')" type="primary" @click="edit()"
        >编写公告</a-button
      ></template
    ><template #date="{ record }">{{
      new Date(record.publishedAt * 1000).toLocaleString("zh-CN")
    }}</template></gi-table
  >
  <section v-if="editing" class="surface detail-section">
    <h2>{{ tab === "announcements" ? "发布公告" : "运营内容" }}</h2>
    <a-alert v-if="error" type="error">{{ error }}</a-alert
    ><a-form :model="form" layout="vertical"
      ><a-form-item v-if="tab === 'content'" label="类型"
        ><a-select v-model="form.kind"
          ><a-option value="faq">FAQ</a-option
          ><a-option value="banner">Banner</a-option
          ><a-option value="activity">活动</a-option></a-select
        ></a-form-item
      ><a-form-item label="标题"
        ><a-input
          v-model="form.title"
          :input-attrs="{ 'aria-label': '运营标题' }" /></a-form-item
      ><a-form-item label="正文"
        ><a-textarea
          v-model="form.body"
          :textarea-attrs="{ 'aria-label': '运营正文' }"
          :auto-size="{ minRows: 5, maxRows: 15 }" /></a-form-item
      ><a-form-item v-if="tab === 'content'" label="启用"
        ><a-switch v-model="form.enabled" /></a-form-item
      ><a-space
        ><a-popconfirm
          v-if="tab === 'announcements'"
          content="此公告将出现在 APP 消息中心，确认发布？"
          @ok="save"
          ><a-button type="primary" :loading="saving"
            >发布到消息中心</a-button
          ></a-popconfirm
        ><a-button v-else type="primary" :loading="saving" @click="save"
          >保存内容</a-button
        ><a-button @click="editing = false">取消</a-button></a-space
      ></a-form
    >
  </section>
</template>
