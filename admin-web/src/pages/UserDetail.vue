<script setup lang="ts">
import { useRoute } from "vue-router";
import PageHeader from "../components/PageHeader.vue";
import { api } from "../api/console";
import { useResource } from "../composables/useResource";
const route = useRoute();
const { data, loading, error, refresh } = useResource(() =>
  api.user(String(route.params.id)),
);
void refresh();
</script>
<template>
  <page-header title="用户详情" description="账号与运行状态概览"
    ><a-button @click="$router.back()">返回</a-button
    ><a-button @click="refresh">刷新</a-button></page-header
  ><a-alert v-if="error" type="error">{{ error }}</a-alert
  ><a-spin :loading="loading" class="block"
    ><section v-if="data" class="surface detail-section">
      <h2>{{ data.user.displayName ?? data.user.username }}</h2>
      <a-descriptions :column="2" bordered
        ><a-descriptions-item label="用户 ID">{{
          data.user.id
        }}</a-descriptions-item
        ><a-descriptions-item label="账号">{{
          data.user.username
        }}</a-descriptions-item
        ><a-descriptions-item label="状态">{{
          data.user.disabled ? "已禁用" : "正常"
        }}</a-descriptions-item
        ><a-descriptions-item label="会员">{{
          data.user.member ? "会员" : "免费"
        }}</a-descriptions-item
        ><a-descriptions-item label="注册时间">{{
          new Date(data.user.createdAt * 1000).toLocaleString("zh-CN")
        }}</a-descriptions-item
        ><a-descriptions-item label="最近活跃">{{
          data.user.lastSeenAt
            ? new Date(data.user.lastSeenAt * 1000).toLocaleString("zh-CN")
            : "尚无记录"
        }}</a-descriptions-item
        ><a-descriptions-item label="APP 版本">{{
          data.user.appVersion ?? "未上报"
        }}</a-descriptions-item
        ><a-descriptions-item label="共享账本数量">{{
          data.counts.books
        }}</a-descriptions-item></a-descriptions
      ><a-space class="detail-links"
        ><router-link :to="'/devices?userId=' + data.user.id"
          >查看设备</router-link
        ><router-link :to="'/feedback?userId=' + data.user.id"
          >查看反馈</router-link
        ></a-space
      ><a-alert>管理后台不读取此用户的私人账单与云备份正文。</a-alert>
    </section></a-spin
  >
</template>
