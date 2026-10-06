<script setup lang="ts">
import { reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { Message } from "@arco-design/web-vue";
import { api } from "../api/console";
import { saveSession } from "../api/client";
import { session } from "../state/session";
const props = defineProps<{ target?: { id: string; username: string } }>();
const emit = defineEmits<{ close: [] }>();
const router = useRouter(),
  saving = ref(false),
  error = ref("");
const form = reactive({ currentPassword: "", password: "", confirmation: "" });
const width = Math.min(480, window.innerWidth * 0.9);
async function save() {
  if (form.password !== form.confirmation) {
    error.value = "两次新密码不一致";
    return;
  }
  saving.value = true;
  error.value = "";
  try {
    if (props.target)
      await api.resetAdminPassword(props.target.id, form.password);
    else {
      await api.changePassword(form.currentPassword, form.password);
      saveSession(null);
      session.admin = null;
    }
    Message.success(
      props.target ? "密码已重置，旧会话已撤销" : "密码已修改，请重新登录",
    );
    emit("close");
    if (!props.target) await router.replace("/login");
  } catch (e) {
    error.value = e instanceof Error ? e.message : "修改失败";
  } finally {
    saving.value = false;
  }
}
</script>
<template>
  <a-drawer
    :visible="true"
    :title="target ? '重置 ' + target.username + ' 的密码' : '修改我的密码'"
    :width="width"
    :footer="false"
    @cancel="emit('close')"
  >
    <a-alert class="notice">修改后该账号的全部管理会话会失效。</a-alert
    ><a-alert v-if="error" type="error">{{ error }}</a-alert>
    <a-form :model="form" layout="vertical" @submit-success="save">
      <a-form-item
        v-if="!target"
        label="当前密码"
        field="currentPassword"
        required
        ><a-input-password
          v-model="form.currentPassword"
          autocomplete="current-password"
          :input-attrs="{ 'aria-label': '当前密码' }"
      /></a-form-item>
      <a-form-item label="新密码（至少 12 位）" field="password" required
        ><a-input-password
          v-model="form.password"
          autocomplete="new-password"
          :input-attrs="{ 'aria-label': '新密码（至少 12 位）' }"
      /></a-form-item>
      <a-form-item label="确认新密码" field="confirmation" required
        ><a-input-password
          v-model="form.confirmation"
          autocomplete="new-password"
          :input-attrs="{ 'aria-label': '确认新密码' }"
      /></a-form-item>
      <a-button type="primary" html-type="submit" :loading="saving"
        >保存密码</a-button
      >
    </a-form>
  </a-drawer>
</template>
