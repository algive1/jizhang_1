<script setup lang="ts">
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import { api } from "../api/console";
import { useResource } from "../composables/useResource";
const route = useRoute(),
  copied = ref(false);
const { data, loading, error, refresh } = useResource(() =>
  api.trace(String(route.params.userId), String(route.params.traceId)),
);
void refresh();
const labels: Record<string, string> = {
  notification: "收到支付通知",
  page: "Accessibility 页面命中",
  parsed: "提取金额与渠道",
  matched: "通知与页面匹配",
  candidate: "生成候选账单",
  overlay: "展示确认浮层",
  confirmed: "用户确认",
  ignored: "用户忽略",
  saved: "写入本地数据库",
  synced: "云端同步",
};
const stages = computed(() =>
  Object.entries(labels).map(([key, label]) => ({
    key,
    label,
    seen: data.value?.observedStages.includes(key),
  })),
);
async function copy() {
  if (!data.value) return;
  try {
    const diagnostic = {
      traceId: route.params.traceId,
      events: data.value.events.map((e) => ({
        eventId: e.eventId,
        occurredAt: e.occurredAt,
        stage: e.stage,
        status: e.status,
        packageName: e.packageName,
        appVersion: e.appVersion,
        ruleVersion: e.ruleVersion,
        reason: e.reason,
        metadata: JSON.parse(e.metadataJson) as unknown,
      })),
    };
    await navigator.clipboard.writeText(JSON.stringify(diagnostic, null, 2));
    copied.value = true;
    Message.success("已复制白名单诊断信息");
  } catch {
    Message.error("复制失败，请检查浏览器剪贴板权限");
  }
}
</script>
<template>
  <page-header
    title="自动记账事件时间轴"
    :description="'Trace · ' + String(route.params.traceId)"
    ><a-button @click="$router.back()">返回</a-button
    ><a-button @click="refresh">刷新</a-button
    ><a-button :disabled="!data" @click="copy">{{
      copied ? "已复制" : "复制诊断信息"
    }}</a-button></page-header
  ><a-alert v-if="error" type="error">{{ error }}</a-alert
  ><a-spin :loading="loading" class="block"
    ><template v-if="data"
      ><section class="surface detail-section">
        <h2>链路观测状态</h2>
        <div class="stage-grid">
          <div v-for="stage in stages" :key="stage.key">
            <a-tag :color="stage.seen ? 'green' : 'gray'">{{
              stage.seen ? "已观测" : "未上报"
            }}</a-tag
            ><span>{{ stage.label }}</span>
          </div>
        </div>
        <p class="muted">{{ data.integration }}</p>
      </section>
      <section class="surface detail-section">
        <h2>事件记录</h2>
        <a-timeline
          ><a-timeline-item
            v-for="event in data.events"
            :key="event.eventId"
            :dot-color="
              event.status === 'failed'
                ? '#bd4949'
                : event.status === 'pending'
                  ? '#b48543'
                  : '#42695a'
            "
            :label="
              new Date(event.occurredAt).toLocaleTimeString('zh-CN', {
                hour12: false,
              }) +
              '.' +
              String(event.occurredAt % 1000).padStart(3, '0')
            "
            ><div class="timeline-entry">
              <strong>{{ labels[event.stage] ?? event.stage }}</strong
              ><a-tag :color="event.status === 'failed' ? 'red' : 'green'">{{
                event.status
              }}</a-tag>
              <p>
                {{ event.packageName }} · APP {{ event.appVersion }} · 规则
                {{ event.ruleVersion ?? "未上报" }}
              </p>
              <a-alert
                v-if="event.reason"
                :type="event.status === 'failed' ? 'error' : 'info'"
                >{{ event.reason }}</a-alert
              >
              <pre>{{
                JSON.stringify(JSON.parse(event.metadataJson), null, 2)
              }}</pre>
            </div></a-timeline-item
          ></a-timeline
        >
      </section></template
    ><a-empty v-else-if="!loading && !error" description="事件链不存在"
  /></a-spin>
</template>
