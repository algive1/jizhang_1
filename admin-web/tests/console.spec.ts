import {test,expect} from '@playwright/test';
test('P0 login, dashboard, user detail, versions and responsive layout',async({page})=>{
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('/');await expect(page).toHaveURL(/login/);
  await page.getByLabel('管理员账号',{exact:true}).fill('browser_admin');await page.getByLabel('密码',{exact:true}).fill('browser-test-password-2026');await page.getByRole('button',{name:'登录',exact:true}).click();
  await expect(page.getByRole('heading',{name:'工作台',exact:true})).toBeVisible();await expect(page.getByText('尚未收到设备版本上报')).toBeVisible();
  await page.setViewportSize({width:1440,height:1000});await page.screenshot({path:'test-results/p0-dashboard-desktop.png',fullPage:true});
  await page.getByRole('link',{name:'用户管理',exact:true}).click();await expect(page.getByRole('link',{name:'浏览器测试用户',exact:true})).toBeVisible();await page.getByRole('link',{name:'浏览器测试用户',exact:true}).click();await expect(page.getByRole('heading',{name:'用户详情'})).toBeVisible();
  await page.getByRole('link',{name:'版本与灰度发布',exact:true}).click();await page.getByRole('button',{name:'新建版本',exact:true}).click();
  await page.getByLabel('versionName',{exact:true}).fill('3.0.0');await page.getByLabel('versionCode',{exact:true}).fill('300');await page.getByLabel('最低支持版本',{exact:true}).fill('1.0.0');await page.getByLabel('下载地址（HTTPS）',{exact:true}).fill('https://example.com/browser-test.apk');await page.getByLabel('更新日志',{exact:true}).fill('浏览器自动化测试版本');await page.getByRole('button',{name:'保存草稿'}).click();await expect(page.getByRole('cell',{name:'3.0.0',exact:true})).toBeVisible();
  await page.getByRole('link',{name:'远程配置',exact:true}).click();await page.getByRole('button',{name:'新建修订'}).click();await page.getByLabel('标识',{exact:true}).fill('browser.features');await page.getByLabel('修改备注',{exact:true}).fill('浏览器测试');await page.getByRole('button',{name:'保存新修订'}).click();await expect(page.getByRole('cell',{name:'browser.features',exact:true})).toBeVisible();
  await page.setViewportSize({width:390,height:844});await page.screenshot({path:'test-results/p0-config-mobile.png',fullPage:true});await expect(page.getByRole('button',{name:'展开菜单'})).toBeVisible();await page.getByRole('button',{name:'展开菜单'}).click();await expect(page.getByRole('link',{name:'用户管理',exact:true})).toBeVisible();
  expect(errors).toEqual([]);
});
test('support role sees only granted menus and direct API refuses publishing',async({page})=>{
  await page.goto('/login');await page.getByLabel('管理员账号',{exact:true}).fill('browser_support');await page.getByLabel('密码',{exact:true}).fill('browser-test-password-2026');await page.getByRole('button',{name:'登录',exact:true}).click();await expect(page.getByRole('heading',{name:'用户管理',exact:true})).toBeVisible();
  await expect(page.getByRole('link',{name:'版本与灰度发布',exact:true})).toHaveCount(0);await expect(page.getByRole('button',{name:'禁用',exact:true})).toHaveCount(0);
  const status=await page.evaluate(async()=>{const token=sessionStorage.getItem('haohao-console-session');return (await fetch('/api/v1/console/releases',{headers:{Authorization:`Bearer ${token}`}})).status;});expect(status).toBe(403);
});
test('P1 failure trace and versioned rule editing use real APIs',async({page})=>{
  await page.goto('/login');await page.getByLabel('管理员账号',{exact:true}).fill('browser_admin');await page.getByLabel('密码',{exact:true}).fill('browser-test-password-2026');await page.getByRole('button',{name:'登录',exact:true}).click();
  await page.getByRole('link',{name:'失败案例',exact:true}).click();await expect(page.getByRole('cell',{name:'database_write_failed',exact:true})).toBeVisible();await page.getByRole('link',{name:'时间轴',exact:true}).click();
  await expect(page.getByRole('heading',{name:'自动记账事件时间轴'})).toBeVisible();await expect(page.getByRole('list').getByText('通知与页面匹配',{exact:true})).toBeVisible();await expect(page.getByText('database_write_failed',{exact:true})).toBeVisible();
  await page.setViewportSize({width:1440,height:1000});await page.screenshot({path:'test-results/p1-timeline-desktop.png',fullPage:true});
  await page.getByRole('link',{name:'识别与适配规则',exact:true}).click();await page.getByRole('button',{name:'新建修订'}).click();await page.getByLabel('标识',{exact:true}).fill('browser.rule');await page.getByLabel('修改备注',{exact:true}).fill('事件规则测试');
  await page.getByLabel('配置内容',{exact:true}).fill(JSON.stringify({packageName:'com.test.payment',pageIdentifier:'success',activity:'',nodeFeatures:[],textFeatures:['支付成功'],notificationTitlePattern:'',notificationBodyPattern:'',amountPattern:'[0-9]+',merchantPattern:'',priority:100,minAppVersion:'1.0.0',maxAppVersion:null,enabled:true}));await page.getByRole('button',{name:'保存新修订'}).click();await expect(page.getByRole('cell',{name:'browser.rule',exact:true})).toBeVisible();
});
test('P2 model configuration persists and AI metrics show unknown usage honestly',async({page})=>{
  await page.goto('/login');await page.getByLabel('管理员账号',{exact:true}).fill('browser_admin');await page.getByLabel('密码',{exact:true}).fill('browser-test-password-2026');await page.getByRole('button',{name:'登录',exact:true}).click();
  await page.getByRole('link',{name:'模型管理',exact:true}).click();await page.getByRole('button',{name:'新增模型',exact:true}).click();await page.getByLabel('name',{exact:true}).fill('浏览器测试模型');await page.getByLabel('model',{exact:true}).fill('test-model');await page.getByLabel('endpoint',{exact:true}).fill('https://models.example.test');await page.getByLabel('keyRef',{exact:true}).fill('BROWSER_TEST_AI_KEY');await page.getByRole('button',{name:'保存模型',exact:true}).click();await expect(page.getByRole('cell',{name:'浏览器测试模型',exact:true})).toBeVisible();await expect(page.getByText('密钥未配置 · Endpoint 未允许')).toBeVisible();
  await page.getByRole('link',{name:'用量与成本',exact:true}).click();await expect(page.getByRole('heading',{name:'AI 用量与成本'})).toBeVisible();await expect(page.getByText('尚无上游调用记录')).toBeVisible();await expect(page.getByText('0 / 0 次可估价')).toBeVisible();
});
