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
const filters = reactive({
  status: undefined as string | undefined,
  member: undefined as string | undefined,
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
async function toggle(row: User) {
  try {
    await api.setUserStatus(row.id, !row.disabled);
    Message.success("用户状态已更新");
    await table.value?.refresh();
  } catch (e) {
    Message.error(e instanceof Error ? e.message : "操作失败");
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
      ><a-tag :color="record.disabled ? 'red' : 'green'">{{
        record.disabled ? "已禁用" : "正常"
      }}</a-tag></template
    ><template #actions="{ record }"
      ><a-space
        ><router-link :to="'/users/' + record.id">详情</router-link
        ><a-popconfirm
          v-if="can('user:disable')"
          :content="
            record.disabled
              ? '解禁后用户可重新登录'
              : '禁用将撤销用户的在线会话，确认执行？'
          "
          @ok="toggle(record)"
          ><a-button
            type="text"
            size="small"
            :status="record.disabled ? 'normal' : 'danger'"
            >{{ record.disabled ? "解禁" : "禁用" }}</a-button
          ></a-popconfirm
        ></a-space
      ></template
    ></gi-table
  >
</template>
