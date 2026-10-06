<script setup lang="ts">
import { ref } from "vue";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import { api } from "../api/console";
import { useResource } from "../composables/useResource";
import type { Role } from "../api/types";
const { data, loading, error, refresh } = useResource(async () => ({
  roles: await api.roles(),
  permissions: await api.permissions(),
}));
void refresh();
const selected = ref<Role | null>(null),
  saving = ref(false);
function edit(role: Role) {
  selected.value = { ...role, permissions: [...role.permissions] };
}
async function save() {
  if (!selected.value) return;
  saving.value = true;
  try {
    await api.updateRole(selected.value);
    Message.success("角色权限已保存，现有会话即时生效");
    await refresh();
    selected.value = null;
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "保存失败");
  } finally {
    saving.value = false;
  }
}
</script>
<template>
  <page-header
    title="角色与权限"
    description="按职责分配权限。敏感账单权限默认不分配。"
    ><a-button @click="refresh">刷新</a-button></page-header
  ><a-alert v-if="error" type="error">{{ error }}</a-alert
  ><a-spin :loading="loading" class="block"
    ><div class="roles-layout">
      <section class="surface role-list">
        <button
          v-for="role in data?.roles"
          :key="role.id"
          :class="{ selected: selected?.id === role.id }"
          @click="edit(role)"
        >
          <strong>{{ role.name }}</strong
          ><span>{{ role.permissions.length }} 项权限</span>
        </button>
      </section>
      <section class="surface detail-section">
        <template v-if="selected"
          ><h2>{{ selected.name }}</h2>
          <a-input
            v-model="selected.name"
            :disabled="selected.id === 'super'"
            aria-label="角色名称"
          /><a-checkbox-group
            v-model="selected.permissions"
            :disabled="selected.id === 'super'"
            class="permission-grid"
            ><a-checkbox
              v-for="(label, key) in data?.permissions"
              :key="key"
              :value="key"
              ><span>{{ label }}</span
              ><small>{{ key }}</small></a-checkbox
            ></a-checkbox-group
          ><a-button
            v-if="selected.id !== 'super'"
            type="primary"
            :loading="saving"
            @click="save"
            >保存权限</a-button
          >
          <p v-else class="muted">
            超级管理员基础权限受保护；私密账单权限仍未默认授予。
          </p></template
        ><a-empty v-else description="选择左侧角色查看权限" />
      </section></div
  ></a-spin>
</template>
