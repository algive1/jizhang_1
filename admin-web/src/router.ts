import { createRouter, createWebHistory } from "vue-router";
import { session, loadSession, can } from "./state/session";
export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: () => import("./pages/Login.vue") },
    {
      path: "/",
      component: () => import("./components/AdminLayout.vue"),
      children: [
        {
          path: "assistant-policy",
          component: () => import("./pages/AssistantPolicy.vue"),
          meta: { permission: "ai:policy:view" },
        },
        {
          path: "system-maintenance",
          component: () => import("./pages/SystemMaintenance.vue"),
          meta: { permission: "system:maintenance:view" },
        },
        {
          path: "asr",
          component: () => import("./pages/Asr.vue"),
          meta: { permission: "ai:model:view" },
        },
        {
          path: "membership",
          component: () => import("./pages/Membership.vue"),
          meta: { permission: "membership:view" },
        },
        {
          path: "payments",
          component: () => import("./pages/Payments.vue"),
          meta: { permission: "payment:view" },
        },
        {
          path: "payment-channels",
          component: () => import("./pages/PaymentChannels.vue"),
          meta: { permission: "payment:view" },
        },
        {
          path: "",
          component: () => import("./pages/Dashboard.vue"),
          meta: { permission: "dashboard:view" },
        },
        {
          path: "users",
          component: () => import("./pages/Users.vue"),
          meta: { permission: "user:list" },
        },
        {
          path: "users/:id",
          component: () => import("./pages/UserDetail.vue"),
          meta: { permission: "user:view" },
        },
        {
          path: "releases",
          component: () => import("./pages/Releases.vue"),
          meta: { permission: "app:version:view" },
        },
        {
          path: "releases/:id",
          component: () => import("./pages/ReleaseDetail.vue"),
          meta: { permission: "app:version:view" },
        },
        {
          path: "documents/:kind",
          component: () => import("./pages/Documents.vue"),
        },
        {
          path: "roles",
          component: () => import("./pages/Roles.vue"),
          meta: { permission: "system:role" },
        },
        {
          path: "administrators",
          component: () => import("./pages/Administrators.vue"),
          meta: { permission: "system:admin" },
        },
        {
          path: "events/:type?",
          component: () => import("./pages/Events.vue"),
          meta: { permission: "auto-accounting:event:list" },
        },
        {
          path: "trace/:userId/:traceId",
          component: () => import("./pages/EventDetail.vue"),
          meta: { permission: "auto-accounting:event:detail" },
        },
        {
          path: "models",
          component: () => import("./pages/Models.vue"),
          meta: { permission: "ai:model:view" },
        },
        {
          path: "ai-usage",
          component: () => import("./pages/AIUsage.vue"),
          meta: { permission: "ai:usage:view" },
        },
        {
          path: "ai-calls/:id",
          component: () => import("./pages/AICallDetail.vue"),
          meta: { permission: "ai:usage:view" },
        },
        {
          path: "push",
          component: () => import("./pages/Push.vue"),
          meta: { permission: "operations:push:view" },
        },
        {
          path: "push/:id",
          component: () => import("./pages/PushDetail.vue"),
          meta: { permission: "operations:push:view" },
        },
        {
          path: "ledger",
          component: () => import("./pages/Ledger.vue"),
          meta: { permission: "transaction:statistics" },
        },
        {
          path: "operations",
          component: () => import("./pages/Operations.vue"),
          meta: { permission: "operations:view" },
        },
        {
          path: "feedback/:id",
          component: () => import("./pages/FeedbackDetail.vue"),
          meta: { permission: "feedback:view" },
        },
        {
          path: ":pathMatch(.*)*",
          component: () => import("./pages/ResourcePage.vue"),
        },
      ],
    },
  ],
});
router.beforeEach(async (to) => {
  if (to.path === "/login") return;
  try {
    await loadSession();
  } catch {
    return "/login";
  }
  if (!session.admin) return "/login";
  const documentPermission =
    to.params.kind === "rule"
      ? "auto-accounting:rule:view"
      : to.params.kind === "prompt"
        ? "ai:prompt:view"
        : "app:config:view";
  const permission = to.meta.permission as string | undefined;
  if (
    (permission && !can(permission)) ||
    (to.path.startsWith("/documents/") && !can(documentPermission))
  )
    return session.admin.menus[0]?.path ?? "/login";
});
window.addEventListener("session-expired", () => {
  session.admin = null;
  void router.replace("/login");
});
