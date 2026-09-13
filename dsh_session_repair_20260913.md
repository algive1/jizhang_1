# /repair-sessions --fix 任务总结（2026-09-13）

## 一、结论（先说结果）

1. **会话存储没有损坏**：`~/.dsh/sessions` 下全部 **6 个**日志（2 个 v0 legacy + 4 个 v3 当前代）都通过了 DSH 自己的严格校验链路（format catalog v0→v3 迁移 + installed Session 准入 + 真实 `dsh-token-meter` 折叠），**0 个损坏，无需修复**。`--fix` 运行后未写入任何文件（无 `.bak`、无 `.tmp`，文件哈希与运行前完全一致）。
2. `/repair-sessions --fix` 这个命令本身在本机 DSH Desktop 2.0.9 上是**坏的**（误报 + 抛错 + 根本不执行），已定位根因并修复（2 个文件），修复后 CLI 路径已实测通过。
3. 追加发现：在聊天框输入 `/repair-sessions --fix` **不会被执行**，会被当作普通消息交给模型（本次任务就是这样进来的）——同样是命令注册缺陷，已一并修复，但**需要重启 DSH Desktop 才生效**。

---

## 二、问题根因（不是表面现象）

### 根因 1：插件用的解码 API 在本版 DSH 已不存在（导致 100% 误报）
`dsh-codex-sync@1.6.1` 的 `lib/session-repair.mjs` 通过
`require('@deepseek-ai/dsh-session').decodeStorageRecord` 解码日志行。
本机 DSH 2.0.9 的 `dsh-session` **已不再导出 `decodeStorageRecord`**（行编解码器移到未公开的
`dsh-session/lib/types/chunk-rows.js`）。实测结果：

```
decodeStorageRecord → undefined
→ 每一行 JSON.parse 后调用它都抛错 → 被逐行 catch 吞掉 → 解析出 0 条事件
→ isClean([]) 走 TokenMeter → Session 头版本校验失败 "session header version must be 3, got 0"
→ 所有 legacy 日志被判为损坏
```

### 根因 2：`--fix` 直接抛异常，什么都不修
`repairSessionStore({fix:true})` 在写文件前调用 `measure(repaired)` 做校验；
对空事件列表该调用必然抛错，异常未被捕获 → 整个命令失败。在**副本**上复现（未动真实数据）：

```
dry run  : {"total":2,"ok":0,"bad":[两个 legacy 日志],"fixed":[]}
fix run  : THREW: session header version must be 3, got 0
遗留文件 : 只有原始 session.jsonl.zstd（没有 .bak，没有任何修复）
```

### 根因 3：只扫描被淘汰的 v0 日志
旧代码只找文件名 `session.jsonl.zstd`。本版 DSH 会话目录里是**代际日志**：
`session.jsonl.zstd` = v0（legacy），`session.v3.jsonl.zstd` = v3（当前），**读取时选取版本号最高的那一代**。
所以旧代码扫描的正好是 DSH 不读的那份文件。

### 根因 4：用宽松恢复路径校验，掩盖了真实的 seam 损坏
本版 DSH 的解码器有两种恢复模式（`dsh-session-format-v1-to-v2/lib/index.js:219-261`）：

| 模式 | 行为 |
|---|---|
| `recoverable`（读路径） | 遇到首个畸形行或 seq gap 就**静默丢掉后面全部内容** |
| `strict`（写/迁移路径，即切模型、压缩那一条） | 直接抛错 → 就是用户看到的报错 |

旧代码按“宽松能过”就算健康，因此漏掉了“读起来变短、写打不开”的 seam 类损坏。

### 根因 5：聊天框命令带参数时不会被认领（所以命令落到了模型）
`dsh-client-ui-commands/lib/client.js:747-751` 的 enter 决策表：

```js
if (desc.input !== void 0) { ... return { claim: leadingClaim(...) } }
if (!bare) return void 0;      // ← 没有声明 input 的命令 + 带参数 → 不认领，按普通消息发送
```

`dsh-cordis` 内置命令 `/permission` 的注册长这样：`input: { hint: '<preset>' }`
（`dsh-permission-presets/lib/index.js`）。而本插件注册 `repair-sessions` 时**没有声明 `input`**，
于是 `/repair-sessions --fix`（`bare=false`）不被认领 → 作为用户消息进入对话。
DSH 日志也证实：会话日志里只有 `agent/inbox/spliced` + `user/message`，**没有** `command/run`；
而内置 `permission` 命令有配对的 `command/run` / `command/done`。

---

## 三、修改了哪些文件 / 核心逻辑

补丁包在 `dsh-patches/`，并已安装进当前 profile（`~/.dsh/profiles/desktop/node_modules/dsh-codex-sync/lib/`）。

| 文件 | 说明 |
|---|---|
| `dsh-patches/session-repair.mjs` | 重写的修复/校验核心（约 26 KB） |
| `dsh-patches/index.js` | 插件命令注册，加一行 `input: { hint: '[--fix] [--root <dir>]' }` |
| `dsh-patches/session-repair.1.6.1.orig.mjs` | 上游原文件备份，便于 diff / 回滚 |
| `dsh-patches/apply.sh` | 重新安装补丁（插件升级后会覆盖，需重跑） |
| `dsh-patches/README.md` | 补丁说明、验证命令、已知限制 |
| `dsh-patches/tests/verify-store.mjs` | 真实存储体检（损坏则 exit 1） |
| `dsh-patches/tests/damage-classes.mjs` | 四类损坏 + in-use 保护的回归测试 |

### `session-repair.mjs` 核心改动
1. **自带多帧 zstd 解码**：移植 `dsh-session-persistence-jsonl` 的 `scanZstdFrames`
   （DSH 的日志是“头部帧 + 每次追加一帧”的拼接容器；`zstdDecompressSync` 只能解第一帧，实测确认）。
   不再依赖外部 `zstd` 命令，也不再依赖 `decodeStorageRecord`。
2. **按 DSH 真实路径校验**：`sessionFormatCatalog.createRestore(..., { recovery: 'strict', validation: 'transformed' })`
   → `Session.fromRestore` 准入 → 真实 `TokenMeter.measure()`。宽松路径另设 `checkLogRecoverable()` 用于区分“可见报错”和“静默截断”。
3. **扫描全部代际日志**（v0 + vN），并按 session 目录标注“已被更高版本取代”。
4. **按真实语义修 `sourceEventSeqs`**：用 `decodeSeqRanges`/`encodeSeqRanges` 处理
   `[start,end]` 区间编码（旧代码把它当单个 seq 过滤，会写坏数据）；seam 只重映射**尾部行**的引用（头部行引用本就正确，旧逻辑会错误地把头部引用指到重复的尾部事件上）。
5. **写前写后双重校验**：修复结果先用严格校验通过才写；写完再读回校验，不通过就用 `.bak` 回滚。
6. **安全护栏**：被 `lsof` 判定正被进程占用的日志跳过；容器末尾有未完成帧的跳过（很可能正在写入）；
   只有“末尾垃圾行”才允许丢弃修复（中间畸形行拒绝改写）；已存在的 `.bak` 不覆盖。

---

## 四、验证结果（可复现）

真实存储体检（严格链路）：

```
$ cd dsh-patches && ELECTRON_RUN_AS_NODE=1 DSH_CHECKOUT="<asar>/node_modules" \
    "/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop" tests/verify-store.mjs
root: /Users/algive/.dsh/sessions
scan: 6 logs, 6 clean, 0 damaged        # exit 0
```

按 session 逐个迁移 + TokenMeter 折叠（修复前实测，全部干净）：

| 日志 | 存储版本 | 行数 | 迁移后事件 | Meter |
|---|---|---|---|---|
| session-10a17fcb … session.jsonl.zstd | 0 | 27 | 29 | clean (8866 tok) |
| session-10a17fcb … session.v3.jsonl.zstd | 3 | 30 | 30 | clean (8866 tok) |
| session-129883f1 … session.v3.jsonl.zstd | 3 | 239 | 239 | clean (82855 tok) |
| session-2ce494ae … session.v3.jsonl.zstd | 3 | 10 | 10 | clean (0 tok) |
| session-abebb320 … session.jsonl.zstd | 0 | 17 | 19 | clean (8857 tok) |
| session-abebb320 … session.v3.jsonl.zstd | 3 | 31 | 31 | clean (9160 tok) |

修复后的 `--fix`（真实存储，无写入）：

```
$ ... bin/dsh-codex-sync.js repair-sessions --fix
scan: 6 logs in /Users/algive/.dsh/sessions, 6 clean, 0 damaged
# 之后：find ~/.dsh/sessions -name '*.bak' → 空；5 个非活动日志哈希与运行前完全一致
```

损坏类回归测试（fixture 全部取自真实日志行，只制造待测的那一处损坏）——`ALL CHECKS PASSED`：

| 用例 | 修复前 | 修复后 |
|---|---|---|
| healthy | strict clean(137) | 未改动（哈希一致） |
| missingStep（缺 step/start、step/end） | strict 报 `token meter: assistant/message at seq 23 has no matching step/start`，宽松读只剩 101/137 事件 | strict clean(135)，DSH 写打开成功 |
| seam（重写头 + 旧游标尾，seq 回绕） | strict 报 `released v2 row 137 has seq gap`，宽松读直接报错 | strict clean(264)，DSH 写打开成功（尾部 127 条事件被救回） |
| trailingRow（末行写一半） | strict 报 `line 139 is not a JSON row` | strict clean(137)，已丢弃残行 |
| locked（文件被进程占用） | — | 跳过不写，文件保持原样 |

另外：`interiorGarbage`（中间畸形行）与 `tornFrame`（容器末尾未完成帧）**明确报告并拒绝改写**，符合“不写入未经校验的修复”。

---

## 五、仍需注意的风险 / 限制

1. **运行中的 DSH 仍在使用旧代码**：本 profile 的 `hmr` 是 `disabled: true`（`dsh --profile desktop --dump-config` 可见），
   补丁只在**下次加载插件时**生效 → **请重启 DSH Desktop**；重启后 `/repair-sessions --fix` 在聊天框会被正常认领并执行。
   （命令行路径现在就已可用，已实测。）
2. 补丁写在 `node_modules` 里，**插件升级（dsh-market 更新）会覆盖**，需重跑 `sh dsh-patches/apply.sh`。
   该操作采用“先复制再 rename”的方式，不会污染 pnpm store（已确认 link 数 = 1）。
3. 修复器的已知不做的事（都会明确报告、不会半修）：
   打包 chunk 行（`text-chunks`/`reasoning-chunks`/`tool-call-chunks`）拒绝重排；
   非 `append` 的 surface op（如 `replace`）自带的 seq 引用没有重映射——若因此严格校验不过，原文件保持不动；
   容器末尾未完成帧、文件被占用时跳过。
4. 同类缺陷还存在于兄弟命令：`import-codex`、`export-codex`、`codex-setting`、`codex-skill`、`codex-mcp`、`auto-import`
   都读 `rawInput` 但没声明 `input`，因此**带参数时同样不会被聊天框认领**。
   本次只改了任务相关的 `repair-sessions`（最小改动），如需一并修，加同样的 `input: { hint: ... }` 即可。
5. 本次验证全部基于本机真实数据 + DSH 自身代码路径；**未做**人为破坏真实会话日志的破坏性测试（fixture 均在 `/tmp`，已清理）。

---

## 六、新窗口继续工作的入口

```sh
# 1) 体检（无写入）
cd /Users/algive/jizhang_01/dsh-patches
ELECTRON_RUN_AS_NODE=1 DSH_CHECKOUT='/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules' \
  '/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop' tests/verify-store.mjs

# 2) 回归测试（自动挑最新 v3 日志造 fixture，跑完自清理）
ELECTRON_RUN_AS_NODE=1 DSH_CHECKOUT='/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules' \
  '/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop' tests/damage-classes.mjs

# 3) 真实修复（本次运行结果：6 clean / 0 damaged，无写入）
ELECTRON_RUN_AS_NODE=1 DSH_CHECKOUT='/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules' \
  '/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop' \
  ~/.dsh/profiles/desktop/node_modules/dsh-codex-sync/bin/dsh-codex-sync.js repair-sessions --fix

# 4) 插件升级后重新打补丁
sh /Users/algive/jizhang_01/dsh-patches/apply.sh
```
