<script setup lang="ts">
import { computed, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  IconApps,
  IconMenuFold,
  IconPoweroff,
  IconSafe,
  IconLock,
} from "@arco-design/web-vue/es/icon";
import { session, signOut } from "../state/session";
import PasswordEditor from "./PasswordEditor.vue";
const route = useRoute(),
  router = useRouter(),
  open = ref(false);
const changingPassword = ref(false);
const groups = computed(() => [
  ...new Set(session.admin?.menus.map((m) => m.group) ?? []),
]);
const title = computed(
  () =>
    session.admin?.menus.find((m) => m.path === route.path)?.title ?? "详情",
);
async function logout() {
  await signOut();
  await router.replace("/login");
}
</script>
<template>
  <div class="admin-layout">
    <button
      v-if="open"
      class="sidebar-backdrop"
      aria-label="关闭菜单"
      @click="open = false"
    />
    <aside class="sidebar" :class="{ open }">
      <a
        class="brand"
        href="/"
        @click.prevent="router.push(session.admin?.menus[0]?.path ?? '/')"
        ><span class="brand-mark"><icon-apps /></span>
        <div>好好记账<span>管理控制台</span></div></a
      >
      <nav aria-label="主导航">
        <div v-for="group in groups" :key="group" class="nav-group">
          <p v-if="group">{{ group }}</p>
          <router-link
            v-for="menu in session.admin?.menus.filter(
              (m) => m.group === group,
            )"
            :key="menu.path"
            :to="menu.path"
            :class="{ selected: route.path === menu.path }"
            @click="open = false"
            >{{ menu.title }}</router-link
          >
        </div>
      </nav>
      <div class="sidebar-footer"><icon-safe /> 隐私优先 · 最小权限</div>
    </aside>
    <main class="workspace">
      <div class="topbar">
        <a-space
          ><a-button
            class="menu-toggle"
            aria-label="展开菜单"
            @click="open = !open"
            ><icon-menu-fold /></a-button
          ><span class="muted">管理控制台</span
          ><span class="breadcrumb-separator">/</span
          ><span>{{ title }}</span></a-space
        ><a-space
          ><a-avatar :size="30" class="admin-avatar">{{
            session.admin?.username.slice(0, 1).toUpperCase()
          }}</a-avatar
          ><span>{{ session.admin?.username }}</span
          ><a-button
            type="text"
            aria-label="修改我的密码"
            @click="changingPassword = true"
            ><icon-lock /></a-button
          ><a-button type="text" aria-label="退出登录" @click="logout"
            ><icon-poweroff /></a-button
        ></a-space>
      </div>
      <div class="page-content"><router-view :key="route.path" /></div>
      <footer class="workspace-footer">
        好好记账管理控制台<span>仅展示服务端已接入数据</span>
      </footer>
    </main>
    <password-editor
      v-if="changingPassword"
      @close="changingPassword = false"
    />
  </div>
</template>
