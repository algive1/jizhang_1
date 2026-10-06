<script setup lang="ts">
import { reactive, ref } from "vue";
import { Message } from "@arco-design/web-vue";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import PasswordEditor from "../components/PasswordEditor.vue";
import { api } from "../api/console";
import { session } from "../state/session";
import type { Role, Administrator } from "../api/types";
const table = ref<{ refresh: () => Promise<void> }>(),
  roles = ref<Array<Pick<Role, "id" | "name">>>([]),
  editing = ref(false),
  error = ref(""),
  saving = ref(false);
const form = reactive({ username: "", password: "", roleId: "support" });
const target = ref<Administrator | null>(null),
  passwordTarget = ref<Administrator | null>(null);
function edit(row?: Administrator) {
  target.value = row ?? null;
  Object.assign(form, {
    username: row?.username ?? "",
    password: "",
    roleId: row?.roleId ?? "support",
  });
  error.value = "";
  editing.value = true;
}
void api
  .roleOptions()
  .then((v) => {
    roles.value = v;
  })
  .catch((e) => {
    error.value = e instanceof Error ? e.message : "角色加载失败";
  });
const columns: TableColumnData[] = [
  { title: "账号", dataIndex: "username" },
  { title: "角色", dataIndex: "roleId", slotName: "role" },
  {
    title: "状态（1 启用 / 0 禁用）",
    dataIndex: "enabled",
    slotName: "status",
  },
  { title: "创建时间", dataIndex: "createdAt", slotName: "date" },
  { title: "操作", slotName: "actions" },
];
async function save() {
  saving.value = true;
  error.value = "";
  try {
    if (target.value)
      await api.updateAdministrator(
        target.value.id,
        Boolean(target.value.enabled),
        form.roleId,
      );
    else await api.createAdministrator({ ...form });
    form.password = "";
    editing.value = false;
    Message.success(target.value ? "角色已更新，旧会话已撤销" : "管理员已创建");
    await table.value?.refresh();
  } catch (e) {
    error.value = e instanceof Error ? e.message : "创建失败";
  } finally {
    saving.value = false;
  }
}
async function toggle(row: Administrator) {
  try {
    await api.updateAdministrator(row.id, !row.enabled, row.roleId);
    await table.value?.refresh();
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "更新失败");
  }
}
</script>
<template>
  <page-header
    title="管理员"
    description="管理账号使用独立会话，禁用会立即撤销登录。"
  /><a-alert v-if="error" type="error">{{ error }}</a-alert
  ><gi-table ref="table" :load="api.administrators" :columns="columns"
    ><template #toolbar
      ><a-button type="primary" @click="edit()">新增管理员</a-button></template
    ><template #role="{ record }">{{
      roles.find((r) => r.id === record.roleId)?.name ?? record.roleId
    }}</template
    ><template #status="{ record }"
      ><a-tag :color="record.enabled ? 'green' : 'gray'">{{
        record.enabled ? "启用" : "禁用"
      }}</a-tag></template
    ><template #date="{ record }">{{
      new Date(record.createdAt * 1000).toLocaleString("zh-CN")
    }}</template
    ><template #actions="{ record }"
      ><a-space v-if="record.id !== session.admin?.id"
        ><a-button type="text" size="small" @click="edit(record)">角色</a-button
        ><a-button type="text" size="small" @click="passwordTarget = record"
          >重置密码</a-button
        ><a-popconfirm
          content="确认更新状态？此账号的会话将撤销。"
          @ok="toggle(record)"
          ><a-button type="text" size="small">{{
            record.enabled ? "禁用" : "启用"
          }}</a-button></a-popconfirm
        ></a-space
      ></template
    ></gi-table
  >
  <section v-if="editing" class="surface detail-section">
    <h2>{{ target ? "调整管理员角色" : "新增管理员" }}</h2>
    <a-form :model="form" layout="vertical" @submit-success="save"
      ><a-form-item label="账号" field="username" required
        ><a-input
          v-model="form.username"
          autocomplete="off"
          :disabled="Boolean(target)"
          :input-attrs="{ 'aria-label': '管理员账号名称' }" /></a-form-item
      ><a-form-item
        v-if="!target"
        label="密码（至少 12 位）"
        field="password"
        required
        ><a-input-password
          v-model="form.password"
          autocomplete="new-password"
          :input-attrs="{ 'aria-label': '管理员初始密码' }" /></a-form-item
      ><a-form-item label="角色" field="roleId"
        ><a-select v-model="form.roleId"
          ><a-option v-for="role in roles" :key="role.id" :value="role.id">{{
            role.name
          }}</a-option></a-select
        ></a-form-item
      ><a-space
        ><a-button type="primary" html-type="submit" :loading="saving">{{
          target ? "保存角色" : "创建"
        }}</a-button
        ><a-button
          @click="
            editing = false;
            form.password = '';
          "
          >取消</a-button
        ></a-space
      ></a-form
    >
  </section>
  <password-editor
    v-if="passwordTarget"
    :target="passwordTarget"
    @close="passwordTarget = null"
  />
</template>
