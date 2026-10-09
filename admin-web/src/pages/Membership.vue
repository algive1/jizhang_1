<script setup lang="ts">
import { ref, toRaw } from "vue";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import {
  commerce,
  entitlementLabels,
  type CatalogState,
  type Catalog,
} from "../api/commerce";
import { can } from "../state/session";
const state = ref<CatalogState>(),
  draft = ref<Catalog>(),
  note = ref(""),
  error = ref(""),
  busy = ref(false),
  history = ref<{ refresh: () => Promise<void> }>();
async function load() {
  try {
    state.value = await commerce.catalog();
    draft.value = structuredClone(toRaw(state.value.draft));
    for (const version of draft.value.versions)
      version.benefitIds ??= draft.value.benefits.map((b) => b.id);
    note.value = "";
    error.value = "";
  } catch (e) {
    error.value = String(e);
  }
}
async function save() {
  if (!draft.value || !state.value) return;
  busy.value = true;
  try {
    await commerce.saveCatalog(draft.value, state.value.revision, note.value);
    await load();
    await history.value?.refresh();
    Message.success("草稿已保存，发布后 APP 生效");
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
async function publish(revision: number) {
  if (!state.value) return;
  busy.value = true;
  try {
    await commerce.publish(revision, state.value.publishedHash);
    await load();
    Message.success("套餐已发布");
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
function addPlan() {
  if (!draft.value) return;
  draft.value.plans.push({
    id: "plan_" + Date.now(),
    title: "新套餐",
    months: 1,
    priceInCents: 800,
    description: "会员套餐",
    recommended: false,
    versionId: "pro",
    originalPriceInCents: 0,
    tag: "",
    enabled: false,
    sortOrder: draft.value.plans.length,
    rightOverrides: [],
  });
}
function addBenefit() {
  draft.value?.benefits.push({
    id: "benefit_" + Date.now(),
    title: "新权益",
    subtitle: "",
    detail: "权益说明",
    iconUrl: "",
    enabled: true,
    entitlementKeys: [],
  });
}
void load();
</script>
<template>
  <page-header
    title="套餐与权益"
    description="编辑草稿并发布，APP 会员页将读取线上配置。安卓按后台售价支付，iOS 使用 App Store 价格。"
    ><a-button :disabled="busy" @click="load">刷新</a-button
    ><a-button
      v-if="can('membership:edit')"
      type="primary"
      :loading="busy"
      :disabled="!note.trim()"
      @click="save"
      >保存草稿</a-button
    ><a-popconfirm
      v-if="can('membership:publish') && state?.revision"
      content="发布此草稿后将影响新的购买与会员权益，确认发布？"
      @ok="publish(state!.revision)"
      ><a-button :disabled="busy">发布最新草稿</a-button></a-popconfirm
    ></page-header
  >
  <a-alert v-if="error" type="error">{{ error }}</a-alert>
  <a-spin :loading="!draft && !error" class="block"
    ><template v-if="draft && state">
      <section class="surface detail-section">
        <a-space
          ><a-tag>草稿修订 {{ state.revision }}</a-tag
          ><a-input
            v-model="note"
            placeholder="本次修改说明（保存必填）"
            :max-length="300"
            style="width: min(500px, 60vw)"
        /></a-space>
      </section>
      <a-tabs>
        <a-tab-pane key="plans" title="会员套餐"
          ><section class="surface detail-section">
            <a-button v-if="can('membership:edit')" @click="addPlan"
              >新增套餐</a-button
            ><a-collapse style="margin-top: 16px"
              ><a-collapse-item
                v-for="p in draft.plans"
                :key="p.id"
                :header="
                  p.title +
                  ' · ¥' +
                  p.priceInCents / 100 +
                  (p.enabled ? ' · 已启用' : ' · 已下架')
                "
              >
                <a-form
                  :model="p"
                  layout="vertical"
                  :disabled="!can('membership:edit')"
                  ><div class="commerce-grid">
                    <a-form-item label="套餐 ID"
                      ><a-input v-model="p.id" /></a-form-item
                    ><a-form-item label="名称"
                      ><a-input v-model="p.title" /></a-form-item
                    ><a-form-item label="会员等级"
                      ><a-select v-model="p.versionId"
                        ><a-option
                          v-for="v in draft.versions"
                          :key="v.id"
                          :value="v.id"
                          >{{ v.title }}</a-option
                        ></a-select
                      ></a-form-item
                    >
                    <a-form-item label="周期"
                      ><a-select v-model="p.months"
                        ><a-option :value="1">月</a-option
                        ><a-option :value="3">季度</a-option
                        ><a-option :value="12">年</a-option></a-select
                      ></a-form-item
                    ><a-form-item label="售价（元）"
                      ><a-input-number
                        :model-value="p.priceInCents / 100"
                        :min="0.01"
                        :precision="2"
                        @update:model-value="
                          p.priceInCents = Math.round(($event ?? 0) * 100)
                        " /></a-form-item
                    ><a-form-item label="原价（元，0 为不展示）"
                      ><a-input-number
                        :model-value="p.originalPriceInCents / 100"
                        :min="0"
                        :precision="2"
                        @update:model-value="
                          p.originalPriceInCents = Math.round(
                            ($event ?? 0) * 100,
                          )
                        "
                    /></a-form-item>
                    <a-form-item label="每日 AI 共用额度（空值沿用助手策略）"
                      ><a-input-number
                        v-model="p.aiDailyLimit"
                        :min="0"
                        :max="10000" /></a-form-item
                    ><a-form-item label="说明"
                      ><a-input v-model="p.description" /></a-form-item
                    ><a-form-item label="角标"
                      ><a-input v-model="p.tag" :max-length="12" /></a-form-item
                    ><a-form-item label="排序"
                      ><a-input-number
                        v-model="p.sortOrder"
                        :min="0" /></a-form-item
                    ><a-form-item label="启用"
                      ><a-switch v-model="p.enabled" /></a-form-item
                    ><a-form-item label="推荐套餐"
                      ><a-switch v-model="p.recommended"
                    /></a-form-item>
                  </div>
                  <h3>套餐权益覆盖</h3>
                  <a-button
                    @click="
                      p.rightOverrides.push({
                        benefitId: draft!.benefits[0]?.id ?? '',
                        enabled: true,
                        value: '',
                      })
                    "
                    >添加覆盖</a-button
                  ><a-space
                    v-for="(r, i) in p.rightOverrides"
                    :key="i"
                    class="commerce-row"
                    wrap
                    ><a-select
                      v-model="r.benefitId"
                      placeholder="权益"
                      style="width: 180px"
                      ><a-option
                        v-for="b in draft.benefits"
                        :key="b.id"
                        :value="b.id"
                        >{{ b.title }}</a-option
                      ></a-select
                    ><a-switch v-model="r.enabled" /><a-input
                      v-model="r.value"
                      placeholder="展示说明"
                      style="width: 220px"
                    /><a-button @click="p.rightOverrides.splice(i, 1)"
                      >移除覆盖</a-button
                    ></a-space
                  ></a-form
                >
              </a-collapse-item></a-collapse
            >
          </section></a-tab-pane
        >
        <a-tab-pane key="versions" title="等级与权益"
          ><section class="surface detail-section">
            <a-button
              v-if="
                can('membership:edit') &&
                !draft.versions.some((v) => v.id === 'family')
              "
              @click="
                draft.versions.push({
                  id: 'family',
                  title: '家庭会员',
                  description: '家庭会员权益',
                  enabled: false,
                  sortOrder: 1,
                  benefitIds: [],
                })
              "
              >增加家庭等级</a-button
            >
            <a-form
              v-for="v in draft.versions"
              :key="v.id"
              :model="v"
              layout="vertical"
              :disabled="!can('membership:edit')"
              ><h3>{{ v.id }}</h3>
              <div class="commerce-grid">
                <a-form-item label="名称"
                  ><a-input v-model="v.title" /></a-form-item
                ><a-form-item label="说明"
                  ><a-input v-model="v.description" /></a-form-item
                ><a-form-item label="启用"
                  ><a-switch v-model="v.enabled" /></a-form-item
                ><a-form-item label="等级所含权益（清空为无权益）"
                  ><a-select v-model="v.benefitIds" multiple allow-clear
                    ><a-option
                      v-for="b in draft.benefits"
                      :key="b.id"
                      :value="b.id"
                      >{{ b.title }}</a-option
                    ></a-select
                  ></a-form-item
                >
              </div></a-form
            >
            <a-divider /><a-button
              v-if="can('membership:edit')"
              @click="addBenefit"
              >新增权益</a-button
            ><a-collapse
              ><a-collapse-item
                v-for="b in draft.benefits"
                :key="b.id"
                :header="b.title"
                ><a-form
                  :model="b"
                  layout="vertical"
                  :disabled="!can('membership:edit')"
                  ><div class="commerce-grid">
                    <a-form-item label="权益 ID"
                      ><a-input v-model="b.id" /></a-form-item
                    ><a-form-item label="名称"
                      ><a-input v-model="b.title" /></a-form-item
                    ><a-form-item label="简述"
                      ><a-input v-model="b.subtitle" /></a-form-item
                    ><a-form-item label="说明"
                      ><a-textarea v-model="b.detail" /></a-form-item
                    ><a-form-item label="图标 HTTPS 地址"
                      ><a-input v-model="b.iconUrl" /></a-form-item
                    ><a-form-item label="启用"
                      ><a-switch v-model="b.enabled" /></a-form-item
                    ><a-form-item label="实际功能权限"
                      ><a-select v-model="b.entitlementKeys" multiple
                        ><a-option
                          v-for="(label, key) in entitlementLabels"
                          :key="key"
                          :value="key"
                          >{{ label }}</a-option
                        ></a-select
                      ></a-form-item
                    >
                  </div></a-form
                ></a-collapse-item
              ></a-collapse
            >
          </section></a-tab-pane
        >
        <a-tab-pane key="faq" title="会员 FAQ"
          ><section class="surface detail-section">
            <a-form
              v-for="f in draft.faqs"
              :key="f.id"
              :model="f"
              layout="vertical"
              :disabled="!can('membership:edit')"
              ><a-form-item label="问题"
                ><a-input v-model="f.question" /></a-form-item
              ><a-form-item label="回答"
                ><a-textarea v-model="f.answer" /></a-form-item
            ></a-form></section
        ></a-tab-pane>
        <a-tab-pane key="history" title="修订与回滚"
          ><gi-table
            ref="history"
            :load="commerce.history"
            :columns="[
              { title: '修订', dataIndex: 'revision' },
              { title: '说明', dataIndex: 'note' },
              { title: '保存时间', slotName: 'date' },
              { title: '操作', slotName: 'actions' },
            ]"
            ><template #date="{ record }">{{
              new Date(record.createdAt * 1000).toLocaleString("zh-CN")
            }}</template
            ><template #actions="{ record }"
              ><a-popconfirm
                v-if="can('membership:publish')"
                content="发布这个历史修订将替换线上套餐，确认执行？"
                @ok="publish(record.revision)"
                ><a-button :disabled="busy">发布此修订</a-button></a-popconfirm
              ></template
            ></gi-table
          ></a-tab-pane
        >
      </a-tabs>
    </template></a-spin
  >
</template>
<style scoped>
.commerce-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 0 20px;
}
.commerce-row {
  display: flex;
  margin-top: 12px;
}
</style>
