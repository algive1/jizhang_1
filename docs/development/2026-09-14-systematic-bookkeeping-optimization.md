# 记一笔与周期账单系统性优化记录

日期：2026-09-14

## 问题原因

- “定期付”此前只切换 transaction 的 `isRecurring` 标记，没有生成真正的周期账单规则。
- 周期账单只有 weekly/monthly 等粗粒度字段，不能表达执行日、间隔、结束次数、提醒提前天数和二级分类。
- 月度计算以“上次日期”为基准，1 月 31 日可能漂移到后续月份的 28/29 日。
- 新增周期账单与当前流水分两步保存，存在一方成功、另一方失败的风险。
- 输入框、选择器、BottomSheet 和操作菜单在页面内重复实现，导致高度、圆角、安全区和小屏适配不一致。
- 图片与普通附件共用相同文件入口，缺少相册、拍照、预览和系统打开能力。

## 已完成

### 公共 UI

- 新增 `AppInput`、`AppTextarea`、`AppSelect`、`AppDatePicker`、`AppTimePicker`、`AppBottomSheet`、`AppActionSheet`、`AppConfirmDialog`、`AppFilePicker`、`AppImagePicker`、`AppContextMenu`、`AppFormRow`。
- 全局 `InputDecorationTheme` 统一为 52px 最小高度、16px 圆角、边框、焦点绿色描边、错误信息和 safe-area 适配。
- `AppSelect` 使用圆角 BottomSheet，选项高度至少 56px，支持选中勾选、Chevron 和长文本省略。
- 旧页面的 `DropdownButtonFormField` 和 `PopupMenuButton` 已迁移到公共组件入口；文本输入框长按仍由系统原生处理。

### 记一笔

- 时间菜单更名为“时间”，提供今天、昨天、前天、自定义日期和时间，并保存日期、时间和时区偏移元数据。
- “定期付”打开周期账单 BottomSheet，首屏字段包括周期、执行日、生效日期、结束规则和提醒，高级选项包括间隔与自动入账。
- 开启周期账单时，先构造当前流水和 recurring bill，再通过同一个数据库事务提交。
- “再记”会清空金额、公式、备注、分类、附件、图片和周期设置，保留账户、账本和不报销状态，时间重置为当前时间。
- 金额公式继续保存 `formula`，同时写入 `amount_formula`，输入为深色，计算结果为绿色。

### 周期账单

- `RecurringBillCycle` 增加 daily；规则支持 `interval`、`weekday`、`dayOfMonth`（含 -1 表示月末）、`month`、`repeatCount`、`completedCount`、`reminderDays` 和 `subcategoryId`。
- 月度、季度、半年和年度执行日使用原始锚点计算，缺少日期时自动取当月最后一天；明确显示“若当月无该日期，将在月末执行”。
- 支持永不结束、指定结束日期、重复 N 次；默认到期生成待确认账单，只有显式开启自动入账才自动影响余额。
- 周期账单详情展示名称、金额、周期、执行日、账户、下一次日期和状态。
- 点击打开详情，长按打开统一操作表：编辑、暂停/恢复、复制、删除；删除二次确认，暂停只更新 `status`。
- schema 从 16 升到 17，`recurring_bills.schedule_json` 保存扩展规则，旧数据默认兼容。

### 附件和图片

- 文件入口与图片入口分开。
- 普通文件支持 PDF、Office、TXT、ZIP 等文件 picker；图片支持相册和拍照，并显示缩略图。
- 附件状态保留 idle/uploading/uploaded/failed，失败时支持重新保存；文件支持系统应用查看、替换和删除。
- iOS 增加相册和相机用途说明；Android 使用现有 file picker/image picker 能力。

### 同步与后端

- 共享同步保留交易元数据中的周期关联、公式、日期、时间和时区字段。
- 周期规则中的二级分类 ID 通过 SharedIdMap 跨账本转换。
- 服务端 recurring bill schema 支持 daily、schedule_json，并校验结束日期、二级分类归属和规则结构。

## 数据关系

当前开启周期账单时：

```text
transaction.metadata_json.recurring_bill_id -> recurring_bills.id
transaction.is_recurring = 1
transaction.is_one_time = 0
```

当前这笔交易仍然是普通流水，参与余额、统计、预算和资产变化；未来日期先保存在 `recurring_bills.next_date`，到期后由前台/Android 调度器生成待确认或自动流水。

## 验证结果

- `flutter analyze --no-pub`：通过，无 issue。
- 周期账单、原子回滚、月末锚点、闰年、重复次数、旧 schema 迁移：通过。
- 记一笔 UI、公式计算、320dp/字号 1.6、小屏不溢出：通过。
- 附件迁移、共享 ID 映射：通过。
- `server npm run typecheck`：通过。
- `server npm test`：10/10 通过。
- Android SDK Platform 34 已安装完成；`flutter build apk --debug --no-pub` 随后在等待阶段被中断，未产生新的 APK。当前未保留构建进程，避免重复 Gradle 写盘。

## 2026-09-14 真机反馈修复

- Android 支付通知自动记账和微信无障碍确认记账，在流水提交成功后共用 `jizhang/bookkeeping_feedback` 通道发送“好好记账 · 记账成功”系统通知；支付通知页首次开启时会请求 Android 13+ 的通知权限。
- “再记”不再调用保存流程，只清空金额、公式、备注、分类、附件、报销和周期配置，保留当前账本与账户。
- 周期账单编辑器补充周期类型和自定义间隔天数，周期设置完成后在“记一笔”页面显示将同时保存首笔流水和周期规则的提示。
- 资产详情、资产分布和资产变化共用的底部弹层移除右上角关闭按钮，保留系统返回和下滑关闭。

本轮定向验证：`flutter analyze --no-pub` 通过；支付通知、周期规则、快速记账和资产交互测试共 26 项通过。尝试重新安装到真机时，设备 `23116PN5BC` 已断开，当前未生成新的 APK，也没有残留构建进程。

## 尚未完成或风险

- 附件目前是本机文档目录持久化，不是远端对象存储；上传进度是本地保存状态。
- 完整历史 Flutter 测试集中仍有少量旧视觉/会员路由断言和资产卡片测试超时，属于既有页面测试与本次公共菜单迁移的兼容差异，需要单独整理旧测试基线。
- 未进行真实 iOS/Android 真机权限和系统文件应用联调；代码已完成，第三方系统能力未实际联调。
