<script setup lang="ts">
import { reactive } from "vue";
import type { ReleaseInput } from "../api/types";
const props = defineProps<{ initial?: ReleaseInput; saving: boolean }>();
const emit = defineEmits<{ save: [form: ReleaseInput] }>();
const form = reactive<ReleaseInput>(
  props.initial
    ? { ...props.initial }
    : {
        platform: "android",
        versionName: "",
        versionCode: 1,
        minimumVersion: "",
        downloadUrl: "",
        changelog: "",
        rollout: 100,
      },
);
</script>
<template>
  <a-form
    :model="form"
    layout="vertical"
    @submit-success="emit('save', { ...form })"
  >
    <a-form-item label="平台" field="platform"
      ><a-select v-model="form.platform"
        ><a-option value="android">Android</a-option
        ><a-option value="ios">iOS</a-option></a-select
      ></a-form-item
    >
    <a-form-item label="versionName" field="versionName" required
      ><a-input
        v-model="form.versionName"
        :input-attrs="{ 'aria-label': 'versionName' }"
        placeholder="例如 1.3.0"
    /></a-form-item>
    <a-form-item label="versionCode" field="versionCode" required
      ><a-input-number
        v-model="form.versionCode"
        :input-attrs="{ 'aria-label': 'versionCode' }"
        :min="1"
        :precision="0"
    /></a-form-item>
    <a-form-item label="最低支持版本" field="minimumVersion" required
      ><a-input
        v-model="form.minimumVersion"
        :input-attrs="{ 'aria-label': '最低支持版本' }"
        placeholder="例如 1.1.0；低于此版本强制更新"
    /></a-form-item>
    <a-form-item label="下载地址（HTTPS）" field="downloadUrl" required
      ><a-input
        v-model="form.downloadUrl"
        :input-attrs="{ 'aria-label': '下载地址（HTTPS）' }"
    /></a-form-item>
    <a-form-item label="灰度百分比" field="rollout"
      ><a-input-number
        v-model="form.rollout"
        :min="0"
        :max="100"
        :precision="0"
    /></a-form-item>
    <a-form-item label="更新日志" field="changelog" required
      ><a-textarea
        v-model="form.changelog"
        :textarea-attrs="{ 'aria-label': '更新日志' }"
        :auto-size="{ minRows: 4, maxRows: 10 }"
    /></a-form-item>
    <a-button type="primary" html-type="submit" :loading="saving"
      >保存草稿</a-button
    >
  </a-form>
</template>
