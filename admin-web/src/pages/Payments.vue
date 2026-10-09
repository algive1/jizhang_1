<script setup lang="ts">
import { reactive, ref } from "vue";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { commerce, orderLabels, type Order } from "../api/commerce";
import { can } from "../state/session";
import { useRoute } from "vue-router";
const route = useRoute(),
  filters = reactive({
    status: "",
    channel: "",
    userId: String(route.query.userId ?? ""),
  }),
  table = ref<{ refresh: () => Promise<void> }>(),
  busy = ref(false),
  refundOrder = ref<Order>(),
  reason = ref(""),
  error = ref("");
const columns = [
  { title: "订单 / 用户", slotName: "order", width: 250 },
  { title: "套餐", dataIndex: "productTitle" },
  { title: "渠道", slotName: "channel" },
  { title: "金额", slotName: "amount" },
  { title: "状态", slotName: "status" },
  { title: "退款", slotName: "refund" },
  { title: "创建时间", slotName: "date" },
  { title: "操作", slotName: "actions", width: 230 },
];
async function action(kind: "refresh" | "close" | "refund", id: string) {
  busy.value = true;
  error.value = "";
  try {
    if (kind === "refund") await commerce.refund(id, reason.value);
    else if (kind === "close") await commerce.closeOrder(id);
    else await commerce.refreshOrder(id);
    refundOrder.value = undefined;
    await table.value?.refresh();
    Message.success("订单状态已更新");
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
</script>
<template>
  <page-header
    title="订单与退款"
    description="以渠道核实的交易结果更新订单。退款仅支持整单，渠道确认完成后扣回此订单发放的会员时长。"
  /><a-alert v-if="error" type="error">{{ error }}</a-alert
  ><gi-table
    ref="table"
    :columns="columns"
    :load="commerce.orders"
    :filters="filters"
    ><template #filters
      ><a-select
        v-model="filters.status"
        placeholder="订单状态"
        allow-clear
        style="width: 150px"
        ><a-option
          v-for="s in ['created', 'pending', 'paid', 'failed', 'refunded']"
          :key="s"
          :value="s"
          >{{ orderLabels[s] }}</a-option
        ></a-select
      ><a-select
        v-model="filters.channel"
        placeholder="支付渠道"
        allow-clear
        style="width: 140px"
        ><a-option value="wechat">微信</a-option
        ><a-option value="alipay">支付宝</a-option></a-select
      ><a-input
        v-model="filters.userId"
        placeholder="用户 ID"
        allow-clear
        style="width: 220px" /></template
    ><template #order="{ record }"
      ><span>{{ record.id }}</span
      ><router-link class="cell-secondary" :to="'/users/' + record.userId">{{
        record.username
      }}</router-link></template
    ><template #channel="{ record }">{{
      record.channel === "wechat" ? "微信" : "支付宝"
    }}</template
    ><template #amount="{ record }"
      >¥{{ (record.amountInCents / 100).toFixed(2) }}</template
    ><template #status="{ record }"
      ><a-tag :color="record.status === 'paid' ? 'green' : 'gray'">{{
        orderLabels[record.status]
      }}</a-tag></template
    ><template #refund="{ record }">{{
      orderLabels[record.refundStatus] ?? "—"
    }}</template
    ><template #date="{ record }">{{
      new Date(record.createdAt * 1000).toLocaleString("zh-CN")
    }}</template
    ><template #actions="{ record }"
      ><a-space
        ><a-button
          v-if="can('payment:reconcile')"
          type="text"
          :disabled="busy"
          @click="action('refresh', record.id)"
          >核实状态</a-button
        ><a-popconfirm
          v-if="
            can('payment:reconcile') &&
            ['created', 'pending'].includes(record.status)
          "
          content="先核实渠道状态，再关闭未支付订单，确认执行？"
          @ok="action('close', record.id)"
          ><a-button type="text" :disabled="busy">关闭</a-button></a-popconfirm
        ><a-button
          v-if="
            can('payment:refund') &&
            record.status === 'paid' &&
            record.refundStatus !== 'succeeded'
          "
          type="text"
          status="danger"
          :disabled="busy"
          @click="
            refundOrder = record;
            reason = '';
          "
          >退款</a-button
        ></a-space
      ></template
    ></gi-table
  ><a-modal
    :visible="!!refundOrder"
    title="整单退款"
    :ok-loading="busy"
    :ok-button-props="{ disabled: !reason.trim() }"
    @cancel="refundOrder = undefined"
    @ok="action('refund', refundOrder!.id)"
    ><p>
      将退回 ¥{{
        ((refundOrder?.amountInCents ?? 0) / 100).toFixed(2)
      }}，渠道确认成功后扣回此订单发放的会员时长。
    </p>
    <a-textarea
      v-model="reason"
      placeholder="退款原因（必填）"
      :max-length="80"
    /><a-alert v-if="error" type="error">{{ error }}</a-alert></a-modal
  >
</template>
