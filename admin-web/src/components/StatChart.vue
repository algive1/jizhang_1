<script setup lang="ts">
import {ref,onMounted,onBeforeUnmount,watch} from 'vue';
import * as echarts from 'echarts';
import type {EChartsOption} from 'echarts';
const props=defineProps<{option:EChartsOption;label:string}>();const element=ref<HTMLDivElement>();let chart:echarts.ECharts|undefined,observer:ResizeObserver|undefined;
onMounted(()=>{if(!element.value)return;chart=echarts.init(element.value);chart.setOption(props.option);observer=new ResizeObserver(()=>chart?.resize());observer.observe(element.value);});
watch(()=>props.option,v=>chart?.setOption(v,true),{deep:true});onBeforeUnmount(()=>{observer?.disconnect();chart?.dispose();});
</script>
<template><div ref="element" class="stat-chart" role="img" :aria-label="label"/></template>
