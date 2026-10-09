<script setup lang="ts">
import { ref } from "vue";
import { Message } from "@arco-design/web-vue";
import PageHeader from "../components/PageHeader.vue";
import { assistantApi, type AssistantPolicySnapshot } from "../api/assistant";
import { can } from "../state/session";
const data = ref<AssistantPolicySnapshot>(),
  loading = ref(false),
  saving = ref(false),
  error = ref("");
const fields = [
  { key: "maxInputLength", label: "每条文字最多字数", min: 20, max: 2000 },
  { key: "requestsPerMinute", label: "每用户每分钟请求数", min: 1, max: 60 },
  { key: "freeDailyLimit", label: "免费用户每日次数", min: 0, max: 10000 },
  { key: "memberDailyLimit", label: "会员默认每日次数", min: 0, max: 10000 },
  { key: "maxTransactions", label: "每次文字或图片最多笔数", min: 1, max: 30 },
  { key: "maxImageMb", label: "图片大小上限 MB", min: 1, max: 20 },
  { key: "maxImportFileMb", label: "表格文件上限 MB", min: 1, max: 50 },
  { key: "maxImportRows", label: "每次导入最多行数", min: 1, max: 10000 },
] as const;
async function refresh() {
  loading.value = true;
  error.value = "";
  try {
    data.value = await assistantApi.read();
  } catch (e) {
    error.value = e instanceof Error ? e.message : "读取失败，请重试";
  } finally {
    loading.value = false;
  }
}
async function save() {
  if (!data.value) return;
  saving.value = true;
  error.value = "";
  try {
    data.value = await assistantApi.save(
      data.value.revision,
      data.value.policy,
    );
    Message.success("助手策略已保存");
  } catch (e) {
    error.value = e instanceof Error ? e.message : "保存失败，请重试";
  } finally {
    saving.value = false;
  }
}
void refresh();
</script>
<template>
  <page-header
    title="助手策略"
    description="统一管理输入限制、使用额度和系统提示词。保存后服务端立即生效，APP 联网时更新本地缓存。"
  >
    <a-button :disabled="loading || saving" @click="refresh">刷新策略</a-button>
    <a-button
      v-if="can('ai:policy:edit')"
      type="primary"
      :disabled="!data || loading"
      :loading="saving"
      @click="save"
      >保存策略</a-button
    >
  </page-header>
  <a-alert v-if="error" type="error" class="notice">{{ error }}</a-alert>
  <a-spin :loading="loading" class="block">
    <a-form
      v-if="data"
      :model="data.policy"
      layout="vertical"
      :disabled="!can('ai:policy:edit') || saving"
    >
      <section class="surface detail-section">
        <h2>使用与输入限制</h2>
        <a-form-item label="启用记账助手"
          ><a-switch v-model="data.policy.enabled" aria-label="启用记账助手"
        /></a-form-item>
        <div class="policy-fields">
          <a-form-item
            v-for="field in fields"
            :key="field.key"
            :label="field.label"
          >
            <a-input-number
              v-model="data.policy[field.key]"
              :min="field.min"
              :max="field.max"
              :input-attrs="{ 'aria-label': field.label }"
            />
          </a-form-item>
        </div>
        <a-form-item label="需要会员权益的功能">
          <a-checkbox-group v-model="data.policy.memberFeatures">
            <a-checkbox value="voice">语音 AI</a-checkbox
            ><a-checkbox value="ocr">图片 AI</a-checkbox>
            <a-checkbox value="export">导出入口</a-checkbox
            ><a-checkbox value="summary">收支查询入口</a-checkbox>
          </a-checkbox-group>
        </a-form-item>
        <p class="muted">
          每日额度按北京时间零点重置；会员套餐额度优先。文字请求通过检查后计一次，拒绝请求不扣次数，模型服务或解析失败返还次数。图片先在设备识别，表格在本地解析、去重并确认导入。
        </p>
      </section>
      <section class="surface detail-section">
        <h2>系统提示词</h2>
        <a-form-item label="基础系统提示词"
          ><a-textarea
            v-model="data.policy.systemPrompt"
            :max-length="8000"
            :auto-size="{ minRows: 5, maxRows: 12 }"
            :textarea-attrs="{ 'aria-label': '基础系统提示词' }"
        /></a-form-item>
        <a-form-item label="超出业务范围的回复"
          ><a-textarea
            v-model="data.policy.boundaryReply"
            :max-length="500"
            :auto-size="{ minRows: 2, maxRows: 5 }"
            :textarea-attrs="{ 'aria-label': '超出业务范围的回复' }"
        /></a-form-item>
        <p class="muted">
          对话实际提示词 = 固定业务边界 + 基础系统提示词 +
          已发布的助手场景要求。交易解析使用独立结构约束，再追加对应场景要求。
        </p>
        <router-link v-if="can('ai:prompt:view')" to="/documents/prompt"
          >管理场景提示词与发布版本</router-link
        >
      </section>
    </a-form>
    <section v-if="data" class="surface detail-section">
      <h2>固定业务约束</h2>
      <p class="muted">
        以下约束由服务端执行和追加，可编辑提示词不能解除身份、额度及交易字段校验。
      </p>
      <a-collapse>
        <a-collapse-item header="助手对话的固定约束" key="chat"
          ><p class="prompt-contract">
            {{ data.assistantHardPrompt }}
          </p></a-collapse-item
        >
        <a-collapse-item header="交易解析的结构约束" key="parse"
          ><p class="prompt-contract">
            {{ data.transactionPrompt }}
          </p></a-collapse-item
        >
      </a-collapse>
    </section>
  </a-spin>
</template>
<style scoped>
.policy-fields {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 24px;
}
.prompt-contract {
  white-space: pre-wrap;
  line-height: 1.7;
  max-width: 75ch;
}
@media (max-width: 720px) {
  .policy-fields {
    grid-template-columns: 1fr;
  }
}
</style>
