<script setup lang="ts" generic="T extends object">
import { computed, ref, watch, onScopeDispose } from "vue";
import type { TableColumnData } from "@arco-design/web-vue";
import {
  IconRefresh,
  IconDownload,
  IconSettings,
} from "@arco-design/web-vue/es/icon";
import type { Page, Query } from "../api/types";
import { useResource } from "../composables/useResource";
const props = defineProps<{
  columns: TableColumnData[];
  load: (query: Query) => Promise<Page<T>>;
  filters?: Query;
  rowKey?: string;
  emptyText?: string;
  selection?: boolean;
  exportValue?: (row: T, column: TableColumnData) => unknown;
}>();
const emit = defineEmits<{
  selectionChange: [keys: Array<string | number>];
  reset: [];
}>();
const selectedKeys = ref<Array<string | number>>([]);
const query = ref({
  page: 1,
  pageSize: 20,
  q: "",
  sort: "createdAt",
  order: "desc",
});
const { data, loading, error, refresh } = useResource(() =>
  props.load({ ...query.value, ...props.filters }),
);
watch(data, () => {
  selectedKeys.value = [];
});
watch(selectedKeys, (keys) => emit("selectionChange", keys));
const visibleKeys = ref(
  props.columns.map((c) => String(c.dataIndex ?? c.slotName)),
);
const compact = ref(window.innerWidth < 760);
const resize = () => {
  compact.value = window.innerWidth < 760;
};
window.addEventListener("resize", resize);
onScopeDispose(() => window.removeEventListener("resize", resize));
const columns = computed(() =>
  props.columns
    .filter((c) =>
      visibleKeys.value.includes(String(c.dataIndex ?? c.slotName)),
    )
    .map((c) => (compact.value ? { ...c, fixed: undefined } : c)),
);
watch(
  () => props.filters,
  () => {
    query.value.page = 1;
    void refresh();
  },
  { deep: true },
);
function search() {
  query.value.page = 1;
  void refresh();
}
function value(row: T, key: string) {
  return (row as Record<string, unknown>)[key];
}
function format(v: unknown) {
  return v == null
    ? "—"
    : typeof v === "object"
      ? JSON.stringify(v)
      : String(v);
}
function exportPage() {
  if (!data.value?.items.length) return;
  const quote = (v: unknown) =>
    '"' +
    format(v)
      .replace(/^[\s\u0000-\u001f]*[=+@-]/, "'$&")
      .replaceAll('"', '""') +
    '"';
  const exportedColumns = columns.value.filter((c) => c.slotName !== "actions");
  const exportedValue = (row: T, column: TableColumnData) => {
    if (props.exportValue) return props.exportValue(row, column);
    const key = String(column.dataIndex ?? column.slotName ?? "");
    const raw = value(row, key);
    if (raw != null && key.endsWith("At")) {
      const timestamp = Number(raw);
      return new Date(
        timestamp < 1e12 ? timestamp * 1000 : timestamp,
      ).toLocaleString("zh-CN");
    }
    return raw != null && key === "costMicroUsd" ? Number(raw) / 1000000 : raw;
  };
  const body = [
    exportedColumns.map((c) => quote(c.title)).join(","),
    ...data.value.items.map((row) =>
      exportedColumns.map((c) => quote(exportedValue(row, c))).join(","),
    ),
  ].join("\r\n");
  const url = URL.createObjectURL(
    new Blob(["\ufeff" + body], { type: "text/csv;charset=utf-8" }),
  );
  const a = document.createElement("a");
  a.href = url;
  a.download = "当前页.csv";
  a.click();
  URL.revokeObjectURL(url);
}
function sort(field: string, direction: string) {
  query.value.sort = field;
  query.value.order = direction === "ascend" ? "asc" : "desc";
  search();
}
void refresh();
defineExpose({ refresh });
</script>
<template>
  <section class="surface table-surface">
    <form class="filters" @submit.prevent="search">
      <a-input
        v-model="query.q"
        placeholder="搜索关键词"
        aria-label="搜索关键词"
        allow-clear
        class="search-input"
      /><slot name="filters" /><a-button html-type="submit" type="primary"
        >查询</a-button
      ><a-button
        @click="
          query.q = '';
          emit('reset');
          search();
        "
        >重置</a-button
      >
    </form>
    <div class="table-toolbar">
      <div>
        <slot name="toolbar" /><slot
          name="batch"
          :selected-keys="selectedKeys"
        /><span class="muted">共 {{ data?.total ?? 0 }} 条</span>
      </div>
      <a-space
        ><a-button aria-label="刷新列表" @click="refresh"
          ><icon-refresh /></a-button
        ><a-button :disabled="!data?.items.length" @click="exportPage"
          ><template #icon><icon-download /></template>导出当前页</a-button
        ><a-popover title="显示列" trigger="click"
          ><a-button aria-label="列设置"><icon-settings /></a-button
          ><template #content
            ><a-checkbox-group v-model="visibleKeys" direction="vertical"
              ><a-checkbox
                v-for="column in props.columns"
                :key="String(column.dataIndex ?? column.slotName)"
                :value="String(column.dataIndex ?? column.slotName)"
                >{{ column.title }}</a-checkbox
              ></a-checkbox-group
            ></template
          ></a-popover
        ></a-space
      >
    </div>
    <a-alert v-if="error" type="error" class="table-error"
      >{{ error
      }}<template #action
        ><a-button size="small" @click="refresh">重试</a-button></template
      ></a-alert
    ><a-table
      v-model:selected-keys="selectedKeys"
      :row-selection="
        selection ? { type: 'checkbox', showCheckedAll: true } : undefined
      "
      :columns="columns"
      :data="data?.items ?? []"
      :loading="loading"
      :pagination="false"
      :row-key="rowKey ?? 'id'"
      :scroll="{ x: 1000 }"
      :bordered="false"
      size="medium"
      @sorter-change="sort"
      ><template #empty
        ><a-empty :description="emptyText ?? '暂无记录'" /></template
      ><template v-for="(_, name) in $slots" #[name]="slotData"
        ><slot :name="name" v-bind="slotData" /></template
    ></a-table>
    <div class="pagination">
      <a-pagination
        :total="data?.total ?? 0"
        :current="Number(query.page)"
        :page-size="Number(query.pageSize)"
        show-page-size
        :page-size-options="[20, 50, 100]"
        @change="
          query.page = $event;
          refresh();
        "
        @page-size-change="
          query.pageSize = $event;
          query.page = 1;
          refresh();
        "
      />
    </div>
  </section>
</template>
