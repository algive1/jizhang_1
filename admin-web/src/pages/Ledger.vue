<script setup lang="ts">
import PageHeader from "../components/PageHeader.vue";
import { api } from "../api/console";
import { useResource } from "../composables/useResource";
const { data, loading, error, refresh } = useResource(api.ledger);
void refresh();
const columns = [
  { title: "维度", dataIndex: "name" },
  { title: "数量", dataIndex: "count" },
];
</script>
<template>
  <page-header
    title="记账数据总览"
    description="聚合已同步数据，私人本地流水与备份正文不纳入统计。"
    ><a-button @click="refresh">刷新</a-button></page-header
  ><a-alert v-if="error" type="error">{{ error }}</a-alert
  ><a-spin :loading="loading" class="block"
    ><template v-if="data"
      ><a-alert class="notice">{{ data.scope }}</a-alert>
      <div class="two-columns">
        <section class="surface detail-section">
          <h2>账本类型</h2>
          <a-table
            :columns="columns"
            :data="data.books.map((r) => ({ name: r.type, count: r.count }))"
            :pagination="false"
            :bordered="false"
          />
        </section>
        <section class="surface detail-section">
          <h2>实体类型</h2>
          <a-table
            :columns="columns"
            :data="data.entities.map((r) => ({ name: r.kind, count: r.count }))"
            :pagination="false"
            :bordered="false"
          />
        </section>
      </div>
      <section class="surface detail-section">
        <h2>流水来源</h2>
        <a-table
          :columns="columns"
          :data="
            data.transactionSources.map((r) => ({
              name: r.source,
              count: r.count,
            }))
          "
          :pagination="false"
          :bordered="false"
        /></section></template
  ></a-spin>
</template>
