<script setup lang="ts">
import { computed, reactive, ref } from "vue";
import { useRoute } from "vue-router";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { api } from "../api/console";
import { can } from "../state/session";
const route = useRoute(),
  more = ref(false);
const filters = reactive({
  stage: route.path.endsWith("notifications")
    ? "notification"
    : route.path.endsWith("pages")
      ? "page"
      : route.path.endsWith("merges")
        ? "matched"
        : undefined,
  status: route.path.endsWith("failures") ? "failed" : undefined,
  packageName: undefined as string | undefined,
  appVersion: undefined as string | undefined,
  ruleVersion: undefined as number | undefined,
  reason: undefined as string | undefined,
  brand: undefined as string | undefined,
  androidVersion: undefined as string | undefined,
});
const title = computed(() =>
  route.path.endsWith("notifications")
    ? "支付通知事件"
    : route.path.endsWith("pages")
      ? "页面识别事件"
      : route.path.endsWith("merges")
        ? "事件合并"
        : route.path.endsWith("failures")
          ? "失败案例"
          : "自动记账事件",
);
const labels: Record<string, string> = {
  notification: "收到通知",
  page: "页面识别",
  parsed: "字段提取",
  matched: "事件匹配",
  candidate: "候选账单",
  overlay: "确认浮层",
  confirmed: "用户确认",
  ignored: "用户忽略",
  saved: "本地写库",
  synced: "云端同步",
};
const columns: TableColumnData[] = [
  { title: "事件链", dataIndex: "traceId", width: 210 },
  { title: "时间", slotName: "time", width: 200 },
  { title: "阶段", slotName: "stage" },
  { title: "结果", slotName: "status" },
  { title: "支付 APP", dataIndex: "packageName", width: 180 },
  { title: "APP 版本", dataIndex: "appVersion" },
  { title: "规则版本", dataIndex: "ruleVersion" },
  { title: "失败原因", dataIndex: "reason", width: 190 },
  { title: "操作", slotName: "actions", fixed: "right", width: 100 },
];
</script>
<template>
  <page-header
    :title="title"
    description="同一用户、同一 trace 的阶段按时间串联。未观测到的阶段不会被推断为失败。"
  /><a-alert class="notice"
    >后台接口已可用。当前 APP 尚未统一上传 trace
    事件，无事件时显示空状态。</a-alert
  ><gi-table
    :columns="columns"
    :load="api.events"
    :filters="filters"
    row-key="eventId"
    empty-text="尚未收到符合条件的事件"
    ><template #filters
      ><a-select
        v-model="filters.stage"
        allow-clear
        placeholder="失败 / 事件阶段"
        style="width: 150px"
        ><a-option v-for="(label, key) in labels" :key="key" :value="key">{{
          label
        }}</a-option></a-select
      ><a-select
        v-model="filters.status"
        allow-clear
        placeholder="结果"
        style="width: 120px"
        ><a-option value="success">成功</a-option
        ><a-option value="failed">失败</a-option
        ><a-option value="pending">等待</a-option></a-select
      ><a-input
        v-model="filters.packageName"
        placeholder="支付 APP 包名"
        allow-clear
        style="width: 200px" /><a-button @click="more = !more">{{
        more ? "收起筛选" : "更多筛选"
      }}</a-button
      ><template v-if="more"
        ><a-input
          v-model="filters.appVersion"
          placeholder="APP 版本"
          allow-clear
          style="width: 140px" /><a-input-number
          v-model="filters.ruleVersion"
          placeholder="规则版本"
          :min="0"
          style="width: 140px" /><a-input
          v-model="filters.reason"
          placeholder="失败原因代码"
          allow-clear
          style="width: 180px" /><a-input
          v-model="filters.brand"
          placeholder="手机品牌"
          allow-clear
          style="width: 140px" /><a-input
          v-model="filters.androidVersion"
          placeholder="Android 版本"
          allow-clear
          style="width: 140px" /></template></template
    ><template #time="{ record }"
      >{{ new Date(record.occurredAt).toLocaleString("zh-CN")
      }}<span class="cell-secondary"
        >{{ String(record.occurredAt % 1000).padStart(3, "0") }} ms</span
      ></template
    ><template #stage="{ record }">{{
      labels[record.stage] ?? record.stage
    }}</template
    ><template #status="{ record }"
      ><a-tag
        :color="
          record.status === 'success'
            ? 'green'
            : record.status === 'failed'
              ? 'red'
              : 'orange'
        "
        >{{
          { success: "成功", failed: "失败", pending: "等待" }[
            record.status as "success" | "failed" | "pending"
          ]
        }}</a-tag
      ></template
    ><template #actions="{ record }"
      ><router-link
        v-if="can('auto-accounting:event:detail')"
        :to="
          '/trace/' +
          encodeURIComponent(record.userId) +
          '/' +
          encodeURIComponent(record.traceId)
        "
        >时间轴</router-link
      ></template
    ></gi-table
  >
</template>
