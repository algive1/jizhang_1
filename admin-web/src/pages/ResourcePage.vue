<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { useRoute } from "vue-router";
import type { TableColumnData } from "@arco-design/web-vue";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { resources } from "../api/resources";
import { can } from "../state/session";
import { api } from "../api/console";
import { useResource } from "../composables/useResource";
const route = useRoute();
const table = ref<{ refresh: () => Promise<void> }>();
async function revoke(id: string) {
  try {
    await api.revokeSession(id);
    Message.success("会话已撤销");
    await table.value?.refresh();
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "撤销失败");
  }
}
const definition = computed(() => resources[route.path]);
const filters = computed(() => ({
  userId:
    typeof route.query.userId === "string" ? route.query.userId : undefined,
}));
const columns = computed<TableColumnData[]>(
  () =>
    definition.value?.columns.map((c) => {
      const name = String(c.dataIndex ?? "");
      return name.endsWith("At")
        ? {
            ...c,
            render: ({ record }) =>
              record[name]
                ? new Date(Number(record[name]) * 1000).toLocaleString("zh-CN")
                : "—",
          }
        : c;
    }) ?? [],
);
const summary = useResource(api.backupSummary);
watch(
  () => route.path,
  (path) => {
    summary.data.value = null;
    if (path === "/backups" && can("backup:status:view"))
      void summary.refresh();
  },
  { immediate: true },
);
</script>
<template>
  <template v-if="definition && can(definition.permission)"
    ><page-header
      :title="definition.title"
      :description="definition.description"
    /><a-alert v-if="definition.notice" type="warning" class="notice">{{
      definition.notice
    }}</a-alert>
    <p v-if="summary.data.value" class="notice muted">
      {{ summary.data.value.storage.datasets }} 个数据集 ·
      {{ summary.data.value.storage.snapshots ?? 0 }} 份快照 ·
      {{ (summary.data.value.storage.bytes / 1048576).toFixed(2) }} MiB
    </p>
    <gi-table
      :key="route.path"
      ref="table"
      :columns="columns"
      :load="definition.load"
      :filters="filters"
      :row-key="definition.rowKey"
      ><template #actions="{ record }"
        ><router-link
          v-if="route.path === '/feedback'"
          :to="'/feedback/' + record.id"
          >详情</router-link
        ><template v-else-if="route.path === '/sessions'"
          ><span v-if="record.current">当前会话</span
          ><a-popconfirm
            v-else
            content="撤销后该会话需要重新登录，确认继续？"
            @ok="revoke(String(record.id))"
            ><a-button type="text" status="danger" size="small"
              >撤销</a-button
            ></a-popconfirm
          ></template
        ></template
      ></gi-table
    ></template
  ><template v-else
    ><page-header
      title="页面不可用"
      description="此页面不存在，或当前账号没有访问权限。"
    /><a-button @click="$router.push('/')">返回工作台</a-button></template
  >
</template>
