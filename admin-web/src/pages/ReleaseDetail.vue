<script setup lang="ts">
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import ReleaseForm from "../components/ReleaseForm.vue";
import { api } from "../api/console";
import { can } from "../state/session";
import { useResource } from "../composables/useResource";
import type { ReleaseInput } from "../api/types";
const route = useRoute();
const { data, loading, error, refresh } = useResource(() =>
  api.release(String(route.params.id)),
);
const editing = ref(false),
  saving = ref(false),
  saveError = ref("");
const initial = computed<ReleaseInput | undefined>(() =>
  data.value
    ? {
        platform: data.value.platform,
        versionName: data.value.versionName,
        versionCode: data.value.versionCode,
        minimumVersion: data.value.minimumVersion,
        downloadUrl: data.value.downloadUrl,
        changelog: data.value.changelog,
        rollout: data.value.rollout,
      }
    : undefined,
);
const date = (value: number | null) =>
  value ? new Date(value * 1000).toLocaleString("zh-CN") : "—";
void refresh();
async function save(input: ReleaseInput) {
  if (!data.value) return;
  saving.value = true;
  saveError.value = "";
  try {
    await api.editRelease(data.value.id, {
      ...input,
      revision: data.value.revision,
    });
    editing.value = false;
    await refresh();
    Message.success("版本草稿已保存");
  } catch (e) {
    saveError.value = e instanceof Error ? e.message : "保存失败";
  } finally {
    saving.value = false;
  }
}
</script>
<template>
  <page-header
    title="APP 版本详情"
    description="发布后内容锁定；更新策略通过版本列表发布或下线。"
    ><router-link to="/releases">返回版本列表</router-link
    ><a-button @click="refresh">刷新</a-button></page-header
  >
  <a-alert v-if="error" type="error">{{ error }}</a-alert>
  <a-spin :loading="loading" class="block"
    ><section v-if="data" class="surface detail-panel">
      <a-descriptions :column="{ xs: 1, sm: 2 }" bordered>
        <a-descriptions-item label="平台">{{
          data.platform
        }}</a-descriptions-item
        ><a-descriptions-item label="发布状态">{{
          { draft: "草稿", published: "已发布", offline: "已下线" }[data.status]
        }}</a-descriptions-item>
        <a-descriptions-item label="版本"
          >{{ data.versionName }} ({{ data.versionCode }})</a-descriptions-item
        ><a-descriptions-item label="最低允许版本">{{
          data.minimumVersion
        }}</a-descriptions-item>
        <a-descriptions-item label="灰度"
          >{{ data.rollout }}%</a-descriptions-item
        ><a-descriptions-item label="修订">{{
          data.revision
        }}</a-descriptions-item>
        <a-descriptions-item label="创建时间">{{
          date(data.createdAt)
        }}</a-descriptions-item
        ><a-descriptions-item label="发布时间">{{
          date(data.publishedAt)
        }}</a-descriptions-item>
        <a-descriptions-item label="更新人">{{
          data.updatedBy ?? "—"
        }}</a-descriptions-item
        ><a-descriptions-item label="更新时间">{{
          date(data.updatedAt)
        }}</a-descriptions-item>
        <a-descriptions-item label="下载地址" :span="2"
          ><a
            :href="data.downloadUrl"
            target="_blank"
            rel="noopener noreferrer"
            >{{ data.downloadUrl }}</a
          ></a-descriptions-item
        >
      </a-descriptions>
      <h2>更新日志</h2>
      <p class="preserve-text">{{ data.changelog }}</p>
      <a-button
        v-if="can('app:version:edit') && data.status === 'draft'"
        type="primary"
        @click="editing = !editing"
        >{{ editing ? "取消编辑" : "编辑草稿" }}</a-button
      >
      <template v-if="editing && initial"
        ><a-alert v-if="saveError" type="error">{{ saveError }}</a-alert
        ><release-form
          :key="data.revision"
          :initial="initial"
          :saving="saving"
          @save="save"
      /></template></section
  ></a-spin>
</template>
<style scoped>
.detail-panel {
  padding: 24px;
}
.preserve-text {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
h2 {
  margin-top: 24px;
}
</style>
