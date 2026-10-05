import {createRouter,createWebHistory} from 'vue-router';
import {session,loadSession,can} from './state/session';
export const router=createRouter({history:createWebHistory(),routes:[
  {path:'/login',component:()=>import('./pages/Login.vue')},
  {path:'/',component:()=>import('./components/AdminLayout.vue'),children:[
    {path:'',component:()=>import('./pages/Dashboard.vue'),meta:{permission:'dashboard:view'}},
    {path:'users',component:()=>import('./pages/Users.vue'),meta:{permission:'user:list'}},
    {path:'users/:id',component:()=>import('./pages/UserDetail.vue'),meta:{permission:'user:view'}},
    {path:'releases',component:()=>import('./pages/Releases.vue'),meta:{permission:'app:version:view'}},
    {path:'documents/:kind',component:()=>import('./pages/Documents.vue')},
    {path:'roles',component:()=>import('./pages/Roles.vue'),meta:{permission:'system:role'}},
    {path:'administrators',component:()=>import('./pages/Administrators.vue'),meta:{permission:'system:admin'}},
    {path:'events/:type?',component:()=>import('./pages/Events.vue'),meta:{permission:'auto-accounting:event:list'}},
    {path:'trace/:userId/:traceId',component:()=>import('./pages/EventDetail.vue'),meta:{permission:'auto-accounting:event:detail'}},
    {path:'models',component:()=>import('./pages/Models.vue'),meta:{permission:'ai:model:view'}},
    {path:'ai-usage',component:()=>import('./pages/AIUsage.vue'),meta:{permission:'ai:usage:view'}},
    {path:':pathMatch(.*)*',component:()=>import('./pages/ResourcePage.vue')},
  ]},
]});
router.beforeEach(async to=>{
  if(to.path==='/login')return;
  try{await loadSession();}catch{return '/login';}
  if(!session.admin)return '/login';
  const documentPermission=to.params.kind==='rule'?'auto-accounting:rule:view':to.params.kind==='prompt'?'ai:prompt:view':'app:config:view';
  const permission=to.meta.permission as string|undefined;
  if((permission && !can(permission)) || (to.path.startsWith('/documents/') && !can(documentPermission)))return session.admin.menus[0]?.path??'/login';
});
window.addEventListener('session-expired',()=>{session.admin=null;void router.replace('/login');});
