<script setup lang="ts">
import { ref, reactive } from "vue";
import { Message } from "@arco-design/web-vue";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { api } from "../api/console";
import { can } from "../state/session";
import type { Release, ReleaseInput } from "../api/types";
const table = ref<{ refresh: () => Promise<void> }>(),
  editing = ref(false),
  saving = ref(false),
  error = ref("");
const filters = reactive({
  platform: undefined as string | undefined,
  status: undefined as string | undefined,
});
const form = reactive<ReleaseInput>({
  platform: "android",
  versionName: "",
  versionCode: 1,
  minimumVersion: "",
  downloadUrl: "",
  changelog: "",
  rollout: 100,
});
const drawerWidth = Math.min(520, Math.max(320, 0.9 * window.innerWidth));
const columns: TableColumnData[] = [
  { title: "平台", dataIndex: "platform", width: 100 },
  { title: "版本", dataIndex: "versionName" },
  { title: "versionCode", dataIndex: "versionCode" },
  { title: "最低支持", dataIndex: "minimumVersion" },
  { title: "灰度范围", slotName: "rollout" },
  { title: "发布状态", slotName: "status" },
  { title: "更新时间", slotName: "date" },
  { title: "操作", slotName: "actions", fixed: "right", width: 220 },
];
async function save() {
  saving.value = true;
  error.value = "";
  try {
    await api.createRelease({ ...form });
    editing.value = false;
    Message.success("版本草稿已创建");
    await table.value?.refresh();
  } catch (e) {
    error.value = e instanceof Error ? e.message : "保存失败";
  } finally {
    saving.value = false;
  }
}
async function state(
  row: Release,
  status: "published" | "offline",
  rollout?: number,
) {
  try {
    await api.releaseState(row.id, status, rollout);
    Message.success("发布策略已更新");
    await table.value?.refresh();
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "更新失败");
  }
}
</script>
<template>
  <page-header
    title="版本与灰度发布"
    description="数据库策略即时用于 APP 版本检查，未发布时沿用原有配置。"
  /><gi-table
    ref="table"
    :columns="columns"
    :load="api.releases"
    :filters="filters"
    ><template #filters
      ><a-select
        v-model="filters.platform"
        allow-clear
        placeholder="平台"
        style="width: 130px"
        ><a-option value="android">Android</a-option
        ><a-option value="ios">iOS</a-option></a-select
      ><a-select
        v-model="filters.status"
        allow-clear
        placeholder="发布状态"
        style="width: 140px"
        ><a-option value="draft">草稿</a-option
        ><a-option value="published">已发布</a-option
        ><a-option value="offline">已下线</a-option></a-select
      ></template
    ><template #toolbar
      ><a-button
        v-if="can('app:version:edit')"
        type="primary"
        @click="editing = true"
        >新建版本</a-button
      ></template
    ><template #rollout="{ record }">{{
      record.rollout === 100 ? "全量" : record.rollout + "% 灰度"
    }}</template
    ><template #status="{ record }"
      ><a-tag :color="record.status === 'published' ? 'green' : 'gray'">{{
        { draft: "草稿", published: "已发布", offline: "已下线" }[
          record.status as Release["status"]
        ]
      }}</a-tag></template
    ><template #date="{ record }">{{
      new Date((record.publishedAt ?? record.createdAt) * 1000).toLocaleString(
        "zh-CN",
      )
    }}</template
    ><template #actions="{ record }"
      ><a-space v-if="can('app:version:publish')"
        ><a-popconfirm
          v-if="record.status !== 'published'"
          content="确认发布此版本策略？"
          @ok="state(record, 'published')"
          ><a-button type="text" size="small">发布</a-button></a-popconfirm
        ><a-popconfirm
          v-else
          content="确认下线？APP 将回退到上一已发布版本或环境配置。"
          @ok="state(record, 'offline')"
          ><a-button type="text" size="small" status="danger"
            >下线</a-button
          ></a-popconfirm
        ><a-popconfirm
          v-if="record.status === 'published' && record.rollout < 100"
          content="确认向所有设备发布？"
          @ok="state(record, 'published', 100)"
          ><a-button type="text" size="small">全量</a-button></a-popconfirm
        ></a-space
      ></template
    ></gi-table
  ><a-drawer
    v-model:visible="editing"
    title="新建版本草稿"
    :width="drawerWidth"
    :footer="false"
    ><a-alert v-if="error" type="error">{{ error }}</a-alert
    ><a-form :model="form" layout="vertical" @submit-success="save"
      ><a-form-item label="平台" field="platform"
        ><a-select v-model="form.platform"
          ><a-option value="android">Android</a-option
          ><a-option value="ios">iOS</a-option></a-select
        ></a-form-item
      ><a-form-item label="versionName" field="versionName" required
        ><a-input
          v-model="form.versionName"
          :input-attrs="{ 'aria-label': 'versionName' }"
          placeholder="例如 1.3.0" /></a-form-item
      ><a-form-item label="versionCode" field="versionCode" required
        ><a-input-number
          v-model="form.versionCode"
          :input-attrs="{ 'aria-label': 'versionCode' }"
          :min="1"
          :precision="0" /></a-form-item
      ><a-form-item label="最低支持版本" field="minimumVersion" required
        ><a-input
          v-model="form.minimumVersion"
          :input-attrs="{ 'aria-label': '最低支持版本' }"
          placeholder="例如 1.1.0；低于此版本强制更新" /></a-form-item
      ><a-form-item label="下载地址（HTTPS）" field="downloadUrl" required
        ><a-input
          v-model="form.downloadUrl"
          :input-attrs="{ 'aria-label': '下载地址（HTTPS）' }" /></a-form-item
      ><a-form-item label="灰度百分比" field="rollout"
        ><a-input-number
          v-model="form.rollout"
          :min="0"
          :max="100"
          :precision="0" /></a-form-item
      ><a-form-item label="更新日志" field="changelog" required
        ><a-textarea
          v-model="form.changelog"
          :textarea-attrs="{ 'aria-label': '更新日志' }"
          :auto-size="{ minRows: 4, maxRows: 10 }" /></a-form-item
      ><a-button type="primary" html-type="submit" :loading="saving"
        >保存草稿</a-button
      ></a-form
    ></a-drawer
  >
</template>
