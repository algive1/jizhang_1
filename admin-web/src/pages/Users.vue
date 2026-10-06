<script setup lang="ts">
import { ref, reactive } from "vue";
import { Message } from "@arco-design/web-vue";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { api } from "../api/console";
import { can } from "../state/session";
import type { User } from "../api/types";
const table = ref<{ refresh: () => Promise<void> }>();
const selected = ref<string[]>([]),
  busy = ref(false);
const filters = reactive({
  status: undefined as string | undefined,
  member: undefined as string | undefined,
  appVersion: undefined as string | undefined,
});
const columns: TableColumnData[] = [
  { title: "用户", slotName: "user", width: 210 },
  {
    title: "注册时间",
    dataIndex: "createdAt",
    slotName: "date",
    sortable: { sortDirections: ["ascend", "descend"] },
  },
  {
    title: "最近活跃",
    dataIndex: "lastSeenAt",
    slotName: "active",
    sortable: { sortDirections: ["ascend", "descend"] },
  },
  { title: "APP / Android", slotName: "version" },
  { title: "设备", slotName: "device" },
  { title: "会员", slotName: "member" },
  { title: "自动记账", slotName: "auto" },
  { title: "云备份", slotName: "backup" },
  { title: "状态", slotName: "status" },
  { title: "操作", slotName: "actions", fixed: "right", width: 170 },
];
const date = (v: number | null) =>
  v ? new Date(v * 1000).toLocaleString("zh-CN") : "尚无记录";
const flag = (v: number | null) =>
  v == null ? "未上报" : v ? "已开启" : "已关闭";
function exported(row: User, column: TableColumnData) {
  switch (column.slotName) {
    case "user":
      return `${row.displayName ?? row.username} (${row.username})`;
    case "date":
      return date(row.createdAt);
    case "active":
      return date(row.lastSeenAt);
    case "version":
      return `${row.appVersion ?? "未上报"} / Android ${row.androidVersion ?? "—"}`;
    case "device":
      return [row.brand, row.model].filter(Boolean).join(" ") || "未上报";
    case "member":
      return row.member ? "会员" : "免费";
    case "auto":
      return flag(row.autoEnabled);
    case "backup":
      return flag(row.backupEnabled);
    case "status":
      return row.accountDisabled ? "已禁用" : "正常";
    default:
      return row[column.dataIndex as keyof User];
  }
}
async function toggle(row: User) {
  try {
    await api.setUserStatus(row.id, !row.accountDisabled);
    Message.success("用户状态已更新");
    await table.value?.refresh();
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "操作失败");
  }
}
async function batch(disabled: boolean) {
  busy.value = true;
  try {
    await api.setUsersStatus(selected.value, disabled);
    Message.success("所选用户状态已更新");
    await table.value?.refresh();
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "操作失败");
  } finally {
    busy.value = false;
  }
}
</script>
<template>
  <page-header
    title="用户管理"
    description="管理账号状态与设备信息。账单内容受独立权限保护。"
  /><gi-table
    ref="table"
    :columns="columns"
    :load="api.users"
    :filters="filters"
    :export-value="exported"
    :selection="can('user:disable')"
    @selection-change="selected = $event.map(String)"
    ><template #filters
      ><a-select
        v-model="filters.status"
        placeholder="账号状态"
        allow-clear
        style="width: 140px"
        ><a-option value="enabled">正常</a-option
        ><a-option value="disabled">已禁用</a-option></a-select
      ><a-select
        v-model="filters.member"
        placeholder="会员状态"
        allow-clear
        style="width: 140px"
        ><a-option value="yes">会员</a-option
        ><a-option value="no">非会员</a-option></a-select
      ><a-input
        v-model="filters.appVersion"
        allow-clear
        placeholder="APP 版本"
        style="width: 140px" /></template
    ><template #batch
      ><a-space v-if="can('user:disable') && selected.length"
        ><a-popconfirm
          :content="
            '禁用所选 ' + selected.length + ' 个用户并撤销会话，确认执行？'
          "
          @ok="batch(true)"
          ><a-button status="danger" :loading="busy"
            >批量禁用</a-button
          ></a-popconfirm
        ><a-popconfirm
          content="解禁所选账号，用户可重新登录。"
          @ok="batch(false)"
          ><a-button :loading="busy">批量解禁</a-button></a-popconfirm
        ></a-space
      ></template
    ><template #user="{ record }"
      ><router-link :to="'/users/' + record.id">{{
        record.displayName ?? record.username
      }}</router-link
      ><span class="cell-secondary">{{ record.username }}</span></template
    ><template #date="{ record }">{{ date(record.createdAt) }}</template
    ><template #active="{ record }">{{ date(record.lastSeenAt) }}</template
    ><template #version="{ record }"
      >{{ record.appVersion ?? "未上报"
      }}<span class="cell-secondary"
        >Android {{ record.androidVersion ?? "—" }}</span
      ></template
    ><template #device="{ record }">{{
      [record.brand, record.model].filter(Boolean).join(" ") || "未上报"
    }}</template
    ><template #member="{ record }"
      ><a-tag :color="record.member ? 'green' : 'gray'">{{
        record.member ? "会员" : "免费"
      }}</a-tag></template
    ><template #auto="{ record }">{{ flag(record.autoEnabled) }}</template
    ><template #backup="{ record }">{{ flag(record.backupEnabled) }}</template
    ><template #status="{ record }"
      ><a-tag :color="record.accountDisabled ? 'red' : 'green'">{{
        record.accountDisabled ? "已禁用" : "正常"
      }}</a-tag></template
    ><template #actions="{ record }"
      ><a-space
        ><router-link :to="'/users/' + record.id">详情</router-link
        ><a-popconfirm
          v-if="can('user:disable')"
          :content="
            record.accountDisabled
              ? '解禁后用户可重新登录'
              : '禁用将撤销用户的在线会话，确认执行？'
          "
          @ok="toggle(record)"
          ><a-button
            type="text"
            size="small"
            :status="record.accountDisabled ? 'normal' : 'danger'"
            >{{ record.accountDisabled ? "解禁" : "禁用" }}</a-button
          ></a-popconfirm
        ></a-space
      ></template
    ></gi-table
  >
</template>
