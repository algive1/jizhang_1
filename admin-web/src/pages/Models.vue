<script setup lang="ts">
import { ref, reactive, computed } from "vue";
import { Message, Modal } from "@arco-design/web-vue";
import type { TableColumnData } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import GiTable from "../components/GiTable.vue";
import { api } from "../api/console";
import { can } from "../state/session";
import type { AIModel, AIModelInput } from "../api/types";
const table = ref<{ refresh: () => Promise<void> }>(),
  editing = ref(false),
  editingId = ref(""),
  error = ref(""),
  saving = ref(false);
const defaults: AIModelInput = {
  name: "",
  provider: "openai-compatible",
  model: "",
  endpoint: "",
  keyRef: "",
  inputPrice: 0,
  outputPrice: 0,
  maxTokens: 512,
  timeoutMs: 30000,
  enabled: false,
  priority: 100,
  fallbackId: null,
  scenes: [],
  dailyBudgetUsd: null,
};
const secret = ref(""),
  keyId = ref(""),
  keySaving = ref(false);
const form = reactive({ ...defaults });
const columns: TableColumnData[] = [
  { title: "名称", dataIndex: "name" },
  { title: "模型 ID", dataIndex: "id", width: 220 },
  { title: "Provider", dataIndex: "provider" },
  { title: "Model", dataIndex: "model" },
  { title: "密钥引用", dataIndex: "keyRef", slotName: "key" },
  { title: "单价 / 百万 Token", slotName: "price" },
  { title: "优先级", dataIndex: "priority" },
  { title: "状态", dataIndex: "enabled", slotName: "status" },
  { title: "操作", slotName: "actions", fixed: "right", width: 220 },
];
function exported(row: AIModel, column: TableColumnData) {
  if (column.slotName === "price")
    return `${row.inputPrice} / ${row.outputPrice} USD`;
  return row[column.dataIndex as keyof AIModel];
}
const load = api.models;
const fallbackId = computed({
  get: () => form.fallbackId ?? "",
  set: (value: string) => {
    form.fallbackId = value || null;
  },
});
const budget = computed({
  get: () => form.dailyBudgetUsd ?? undefined,
  set: (value: number | undefined) => {
    form.dailyBudgetUsd = value ?? null;
  },
});
function edit(row?: AIModel) {
  editingId.value = row?.id ?? "";
  Object.assign(
    form,
    row
      ? {
          name: row.name,
          provider: row.provider,
          model: row.model,
          endpoint: row.endpoint,
          keyRef: row.keyRef,
          inputPrice: row.inputPrice,
          outputPrice: row.outputPrice,
          maxTokens: row.maxTokens,
          timeoutMs: row.timeoutMs,
          enabled: row.enabled,
          priority: row.priority,
          fallbackId: row.fallbackId,
          scenes: [...row.scenes],
          dailyBudgetUsd: row.dailyBudgetUsd,
        }
      : defaults,
  );
  error.value = "";
  editing.value = true;
}
async function save() {
  saving.value = true;
  error.value = "";
  try {
    await api.saveModel(editingId.value || undefined, { ...form });
    editing.value = false;
    Message.success("模型配置已保存");
    await table.value?.refresh();
  } catch (e) {
    error.value = e instanceof Error ? e.message : "保存失败";
  } finally {
    saving.value = false;
  }
}
async function saveKey() {
  keySaving.value = true;
  try {
    await api.saveModelKey(keyId.value, secret.value);
    secret.value = "";
    keyId.value = "";
    Message.success("密钥已加密保存");
    await table.value?.refresh();
  } catch (e) {
    Message.error(String(e));
  } finally {
    keySaving.value = false;
  }
}
function test(row: AIModel) {
  Modal.confirm({
    title: "测试模型连接",
    content: "将真实调用一次模型并计入供应商用量。",
    onOk: async () => {
      try {
        const result = await api.testModel(row.id);
        Message.success(`连接成功，用时 ${result.durationMs} 毫秒`);
      } catch (e) {
        Message.error(String(e));
      }
    },
  });
}
</script>
<template>
  <page-header
    title="模型管理"
    description="配置 DeepSeek 或兼容 OpenAI 接口的模型，设置场景路由、备用模型、超时与单价。"
  /><a-alert class="notice"
    >启用模型需配置服务端 AI_ENDPOINT_ALLOWLIST
    与对应密钥。密钥可由环境变量提供，也可在配置服务端加密主密钥后加密保存。</a-alert
  ><gi-table
    ref="table"
    :columns="columns"
    :load="load"
    :export-value="exported"
    ><template #toolbar
      ><a-button v-if="can('ai:model:edit')" type="primary" @click="edit()"
        >新增模型</a-button
      ></template
    ><template #key="{ record }"
      >{{ record.keyRef
      }}<span class="cell-secondary"
        >{{ record.keyConfigured ? "密钥已配置" : "密钥未配置" }} ·
        {{
          record.endpointAllowed ? "Endpoint 已允许" : "Endpoint 未允许"
        }}</span
      ></template
    ><template #price="{ record }"
      >输入 ${{ record.inputPrice }} / 输出 ${{ record.outputPrice }}</template
    ><template #status="{ record }"
      ><a-tag :color="record.enabled ? 'green' : 'gray'">{{
        record.enabled ? "已启用" : "已停用"
      }}</a-tag></template
    ><template #actions="{ record }"
      ><a-button
        v-if="can('ai:model:edit')"
        type="text"
        size="small"
        @click="edit(record)"
        >编辑</a-button
      ><a-button
        v-if="can('ai:model:edit')"
        type="text"
        size="small"
        @click="
          keyId = record.id;
          secret = '';
        "
        >密钥</a-button
      ><a-button
        v-if="can('ai:model:edit')"
        type="text"
        size="small"
        @click="test(record)"
        >测试</a-button
      ></template
    ></gi-table
  >
  <section v-if="editing" class="surface detail-section">
    <h2>{{ editingId ? "编辑模型" : "新增模型" }}</h2>
    <a-alert v-if="error" type="error">{{ error }}</a-alert
    ><a-form :model="form" layout="vertical" @submit-success="save"
      ><div class="two-columns">
        <a-form-item
          v-for="field in [
            'name',
            'provider',
            'model',
            'endpoint',
            'keyRef',
          ] as const"
          :key="field"
          :label="
            {
              name: '名称',
              provider: 'Provider',
              model: 'Model',
              endpoint: 'Endpoint（基础 HTTPS URL）',
              keyRef: '密钥环境变量引用',
            }[field]
          "
          :field="field"
          required
          ><a-input
            v-model="form[field]"
            :input-attrs="{ 'aria-label': field }" /></a-form-item
        ><a-form-item label="备用模型 ID" field="fallbackId"
          ><a-input
            v-model="fallbackId"
            :input-attrs="{ 'aria-label': '备用模型 ID' }"
            allow-clear /></a-form-item
        ><a-form-item
          v-for="field in [
            'inputPrice',
            'outputPrice',
            'maxTokens',
            'timeoutMs',
            'priority',
          ] as const"
          :key="field"
          :label="
            {
              inputPrice: '输入单价 USD / 百万 Token',
              outputPrice: '输出单价 USD / 百万 Token',
              maxTokens: '最大输出 Token',
              timeoutMs: '超时毫秒',
              priority: '优先级',
            }[field]
          "
          ><a-input-number
            v-model="form[field]"
            :min="0"
            :input-attrs="{ 'aria-label': field }"
        /></a-form-item>
      </div>
      <a-form-item label="适用场景（不选为全部）"
        ><a-select v-model="form.scenes" multiple
          ><a-option value="assistant">智能助手</a-option
          ><a-option value="voice">语音交易解析</a-option
          ><a-option value="ocr">图片文字解析</a-option
          ><a-option value="insight">账务洞察</a-option
          ><a-option value="natural-language">自然语言记账</a-option></a-select
        ></a-form-item
      >
      <a-form-item label="每日估算费用上限 USD（留空不限制）"
        ><a-input-number
          v-model="budget"
          :min="0.01"
          :precision="2"
          placeholder="仅对有 Token 用量的调用估算，超过上限后停止后续调用"
      /></a-form-item>
      <a-form-item label="启用路由"
        ><a-switch v-model="form.enabled" /></a-form-item
      ><a-space
        ><a-button type="primary" html-type="submit" :loading="saving"
          >保存模型</a-button
        ><a-button @click="editing = false">取消</a-button></a-space
      ></a-form
    >
  </section>
  <a-modal
    :visible="Boolean(keyId)"
    title="更新模型密钥"
    :ok-loading="keySaving"
    @ok="saveKey"
    @cancel="
      keyId = '';
      secret = '';
    "
    ><a-input-password
      v-model="secret"
      placeholder="输入新 API Key，保存后不回显"
  /></a-modal>
</template>
