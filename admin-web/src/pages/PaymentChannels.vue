<script setup lang="ts">
import PageHeader from "../components/PageHeader.vue";
import IntegrationEditor from "../components/IntegrationEditor.vue";
</script>
<template>
  <page-header
    title="支付渠道"
    description="配置 APP 支付账号及回调地址，完整密钥仅在服务端保存。真实付款需使用已经开通的商户。"
  /><a-tabs
    ><a-tab-pane key="wechat" title="微信支付"
      ><integration-editor provider="wechat" /></a-tab-pane
    ><a-tab-pane key="alipay" title="支付宝"
      ><integration-editor provider="alipay" /></a-tab-pane
  ></a-tabs>
</template>
