<script setup lang="ts">
import { ref, watch } from "vue";
import { Message } from "@arco-design/web-vue";
import {
  commerce,
  entitlementLabels,
  type MemberDetail,
  type Catalog,
} from "../api/commerce";
import { can } from "../state/session";
const statuses: Record<string, string> = {
  active: "有效",
  expired: "已到期",
  canceled: "已取消",
};
const props = defineProps<{ userId: string }>(),
  emit = defineEmits<{ changed: [] }>(),
  data = ref<MemberDetail>(),
  catalog = ref<Catalog>(),
  productId = ref(""),
  days = ref(30),
  reason = ref(""),
  error = ref(""),
  busy = ref(false);
async function load() {
  if (!can("membership:view")) return;
  try {
    [data.value, catalog.value] = await Promise.all([
      commerce.member(props.userId),
      commerce.catalog().then((v) => v.catalog),
    ]);
    productId.value = data.value.snapshot.subscription?.productId ?? "";
    error.value = "";
  } catch (e) {
    error.value = String(e);
  }
}
async function save() {
  busy.value = true;
  try {
    await commerce.adjust(
      props.userId,
      productId.value || null,
      productId.value ? days.value : 0,
      reason.value,
    );
    await load();
    reason.value = "";
    emit("changed");
    Message.success("会员已调整");
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
watch(
  () => props.userId,
  () => void load(),
  { immediate: true },
);
</script>
<template>
  <section v-if="can('membership:view')" class="surface detail-section">
    <h2>会员与权益</h2>
    <a-alert v-if="error" type="error">{{ error }}</a-alert
    ><template v-if="data"
      ><a-descriptions :column="{ xs: 1, sm: 2 }" bordered
        ><a-descriptions-item label="等级">{{
          data.snapshot.membership.plan
        }}</a-descriptions-item
        ><a-descriptions-item label="状态">{{
          statuses[data.snapshot.membership.status] ??
          data.snapshot.membership.status
        }}</a-descriptions-item
        ><a-descriptions-item label="来源">{{
          data.snapshot.subscription?.provider ?? "免费账号"
        }}</a-descriptions-item
        ><a-descriptions-item label="到期">{{
          data.snapshot.subscription
            ? new Date(
                data.snapshot.subscription.expiresAt * 1000,
              ).toLocaleString("zh-CN")
            : "—"
        }}</a-descriptions-item></a-descriptions
      ><a-space wrap style="margin-top: 16px"
        ><a-tag v-for="e in data.snapshot.entitlements" :key="e.key">{{
          entitlementLabels[e.key] ?? e.key
        }}</a-tag></a-space
      ><a-form
        v-if="can('membership:adjust')"
        :model="{}"
        layout="vertical"
        style="margin-top: 20px"
        ><a-space wrap
          ><a-select
            v-model="productId"
            placeholder="会员套餐"
            style="width: 220px"
            ><a-option value="">普通用户（取消会员）</a-option
            ><a-option v-for="p in catalog?.plans" :key="p.id" :value="p.id">{{
              p.title
            }}</a-option></a-select
          ><a-input-number
            v-if="productId"
            v-model="days"
            :min="1"
            :max="36500"
            placeholder="从现在起有效天数"
            style="width: 200px"
          /><a-input
            v-model="reason"
            placeholder="调整原因"
            :max-length="300"
            style="width: 240px"
          /><a-popconfirm
            content="人工调整将覆盖当前会员状态，确认执行？"
            @ok="save"
            ><a-button :disabled="!reason.trim()" :loading="busy"
              >保存调整</a-button
            ></a-popconfirm
          ></a-space
        ></a-form
      ><router-link :to="'/payments?userId=' + userId">查看支付订单</router-link
      ><a-table
        :data="data.history"
        :pagination="false"
        :columns="[
          { title: '操作者', dataIndex: 'actor' },
          { title: '原因', dataIndex: 'reason' },
          { title: '套餐', dataIndex: 'productId' },
          { title: '天数', dataIndex: 'durationDays' },
        ]"
        style="margin-top: 16px"
    /></template>
  </section>
</template>
