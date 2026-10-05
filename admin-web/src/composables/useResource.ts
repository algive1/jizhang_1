import { ref,shallowRef,onScopeDispose } from 'vue';
export function useResource<T>(loader:()=>Promise<T>) {
  const data=shallowRef<T|null>(null),loading=ref(false),error=ref('');let sequence=0;
  const refresh=async()=>{const current=++sequence;loading.value=true;error.value='';try{const result=await loader();if(current===sequence)data.value=result;}catch(e){if(current===sequence)error.value=e instanceof Error?e.message:'请求失败';}finally{if(current===sequence)loading.value=false;}};
  onScopeDispose(()=>{sequence++;});
  return {data,loading,error,refresh};
}
