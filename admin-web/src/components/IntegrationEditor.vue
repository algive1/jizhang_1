<script setup lang="ts">
import { ref, watch } from "vue";
import { Message } from "@arco-design/web-vue";
import { commerce, type Integration } from "../api/commerce";
import { can } from "../state/session";
const props = defineProps<{ provider: string }>(),
  data = ref<Integration>(),
  values = ref<Record<string, string>>({}),
  error = ref(""),
  busy = ref(false);
const labels: Record<string, string> = {
  WECHAT_APP_ID: "微信 AppID",
  WECHAT_MCH_ID: "商户号",
  WECHAT_SERIAL_NO: "商户证书序列号",
  WECHAT_PLATFORM_SERIAL_NO: "微信公钥 ID / 平台证书序列号",
  WECHAT_NOTIFY_URL: "支付回调 HTTPS 地址",
  WECHAT_REFUND_NOTIFY_URL: "退款回调 HTTPS 地址",
  WECHAT_UNIVERSAL_LINK: "Universal Link",
  WECHAT_PRIVATE_KEY: "商户私钥 PEM",
  WECHAT_PLATFORM_PUBLIC_KEY: "微信验签公钥 PEM",
  WECHAT_API_V3_KEY: "APIv3 密钥",
  ALIPAY_APP_ID: "支付宝 AppID",
  ALIPAY_SELLER_ID: "卖家 ID",
  ALIPAY_NOTIFY_URL: "支付回调 HTTPS 地址",
  ALIPAY_PRIVATE_KEY: "应用私钥 PEM",
  ALIPAY_PUBLIC_KEY: "支付宝公钥 PEM",
  TENCENT_ASR_SECRET_ID: "腾讯 SecretId",
  TENCENT_ASR_SECRET_KEY: "腾讯 SecretKey",
  TENCENT_ASR_ENGINE: "识别引擎",
  TENCENT_ASR_HOTWORD_ID: "热词表 ID",
};
async function load() {
  try {
    data.value = await commerce.integration(props.provider);
    values.value = Object.fromEntries(
      data.value.items.map((i) => [i.name, i.value]),
    );
    error.value = "";
  } catch (e) {
    error.value = String(e);
  }
}
async function save() {
  busy.value = true;
  try {
    await commerce.saveIntegration(props.provider, values.value);
    await load();
    Message.success("接入配置已保存");
  } catch (e) {
    error.value = String(e);
  } finally {
    busy.value = false;
  }
}
watch(
  () => props.provider,
  () => {
    data.value = undefined;
    void load();
  },
  { immediate: true },
);
</script>
<template>
  <a-alert v-if="error" type="error">{{ error }}</a-alert
  ><a-spin :loading="!data && !error" class="block"
    ><section v-if="data" class="surface detail-section">
      <a-alert v-if="!data.canSaveSecrets"
        >服务端尚未设置密钥加密配置，可使用部署环境中的凭据。</a-alert
      ><a-form
        :model="values"
        layout="vertical"
        :disabled="
          !can(provider === 'asr' ? 'ai:model:edit' : 'payment:configure')
        "
        ><div class="integration-grid">
          <a-form-item
            v-for="item in data.items"
            :key="item.name"
            :label="labels[item.name] ?? item.name"
            ><div style="width: 100%">
              <a-textarea
                v-if="
                  item.name.includes('PRIVATE_KEY') ||
                  item.name.includes('PUBLIC_KEY')
                "
                v-model="values[item.name]"
                :placeholder="item.secret ? '留空保留现有值，填写则覆盖' : ''"
                :disabled="item.secret && !data.canSaveSecrets"
                :auto-size="{ minRows: 3, maxRows: 6 }"
              /><a-input-password
                v-else-if="item.secret"
                v-model="values[item.name]"
                placeholder="留空保留现有值"
                :disabled="!data.canSaveSecrets"
              /><a-input v-else v-model="values[item.name]" /><span
                class="cell-secondary"
                >{{
                  !item.readable
                    ? "无法读取，请检查服务端密钥"
                    : item.configured
                      ? "已配置"
                      : "未配置"
                }}
                ·
                {{ item.source === "console" ? "后台配置" : "部署配置" }}</span
              >
            </div></a-form-item
          >
        </div>
        <a-button
          v-if="can(provider === 'asr' ? 'ai:model:edit' : 'payment:configure')"
          type="primary"
          :loading="busy"
          @click="save"
          >保存配置</a-button
        ><a-button :disabled="busy" style="margin-left: 12px" @click="load"
          >刷新状态</a-button
        ></a-form
      >
    </section></a-spin
  >
</template>
<style scoped>
.integration-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 0 24px;
}
</style>
