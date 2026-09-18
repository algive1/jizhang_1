# 源码打包交付（zip）

日期：2026-09-18
范围：把「好好记账」App 相关的全部源码与必要运行资产打包成单个 zip，用于交付、备份或换机器继续开发。
产物：`jizhang_app_source_20260918-2125.zip`（40 MB，627 个文件，解压后顶层目录为 `jizhang_app/`）。

## 结论

- 源码包已生成并通过端到端校验：解压后 627 个文件与工程源目录逐文件 SHA-256 一致，CRC 全部正确，中文文件名可正常还原。
- 打包规则固化为 `scripts/package_source.sh`，之后可一条命令重现，不需要手工挑选文件。
- 打包范围是可编译可运行的最小完整集合；构建产物、依赖缓存、运行时数据库、QA 截图归档均不入包（见下方边界）。

## 打包命令

```bash
# 生成到工程根目录（文件名带时间戳）
./scripts/package_source.sh

# 输出到指定目录
./scripts/package_source.sh --out ~/Desktop

# 只列出将被打包的文件，不生成 zip
./scripts/package_source.sh --list

# 额外包含 docs/qa 的 QA 截图归档（约 46MB，默认不含）
./scripts/package_source.sh --with-qa-docs
```

## 打包内容

```text
jizhang_app/
├── lib/            Flutter 业务源码（app/core/features，209 个 dart 文件）
├── test/           Widget/单元测试（95 个测试文件）
├── assets/         运行期图片与配置（images、membership、config/*.json）
├── android/        Android 原生工程（Kotlin 自动记账、无障碍、通知、图标、启动页）
├── ios/            iOS 原生工程（Runner、Podfile、xcworkspace）
├── server/         Node/TypeScript 共享账本服务（src、test、package.json、README）
├── third_party/    alipay_kit_android 本地补丁包（pubspec dependency_overrides 依赖）
├── scripts/        构建与打包脚本
├── docs/           设计与开发文档（含 design_refs、generated_assets、development）
├── pubspec.yaml / pubspec.lock / analysis_options.yaml / .metadata / .gitignore
└── README.md 及根目录交接、审计 md
```

## 打包边界（有意排除）

| 排除项 | 原因 |
| --- | --- |
| `build/`、`android/app/build/`、`server/dist/` | 编译产物，可由源码重建 |
| `.dart_tool/`、`server/node_modules/`、`android/.gradle/`、`ios/Pods/` | 依赖与缓存，`flutter pub get` / `npm ci` / `pod install` 可重建 |
| `dist/`、`*.apk` | 安装包，约 390MB，不属于源码 |
| `server/data/*.sqlite` | 服务端运行时数据库，含真实账本数据 |
| `docs/qa/` | QA 截图归档，约 46MB；需要时用 `--with-qa-docs` |
| `.git/` | 版本库元数据，不属于源码快照 |
| `android/local.properties`、`ios/Flutter/Generated.xcconfig` | 本机绝对路径，换机器会冲突，Flutter 自动重建 |
| `dsh-patches/`、`strategies/`、`haohaojizhangœ/`、`未命名文件夹/` | 与本记账 App 无关 |
| `.DS_Store`、`*.iml`、`*.log`、`*.zip` | 系统与 IDE 临时文件 |

## 踩过的两个坑

1. **中文文件名双重编码。** macOS 默认 locale 为 `C`，`zip` 与 `ditto -c -k` 都会把中文名写成双重编码字节且不设置 UTF-8 标志位（`flag_bits=0x0`），解压后出现 `σ╣┤`、`???` 之类的乱码。最终改为 Python `zipfile` 写包，非 ASCII 名一律带 `0x800` 标志位，已验证 7 个中文名条目全部正常还原。
2. **heredoc 吞掉脚本后续行。** `python3 - <<'PY'` 会继承脚本 stdin（在外层管道下是管道本身），python 读走剩余内容后，后面 `FILE_COUNT=$(...)` 这类赋值不再执行，报 `unbound variable`。已在脚本中写成 `python3 - "$STAGE" "$OUT_ZIP" < /dev/null <<'PY'`。
   另外 `echo "文件数：$FILE_COUNT，"` 里全角逗号会被 bash 并入变量名，必须写作 `${FILE_COUNT}`。

## 验证记录

```text
$ ./scripts/package_source.sh --out /tmp/jizhang_pack_out
已写入 627 个文件
打包完成：/tmp/jizhang_pack_out/jizhang_app_source_20260918-2125.zip
文件数：627，大小： 40M

# 解压后与源目录逐文件 SHA-256 对比：626+1 文件全部一致，无缺失/无多出/无内容差异
# CRC 完整性：全部 OK；非 ASCII 文件名均带 UTF-8 标志位：True
```

## 换机器继续开发

```bash
unzip jizhang_app_source_20260918-2125.zip
cd jizhang_app
flutter pub get
flutter analyze && flutter test
cd server && npm ci && npm run typecheck && npm test
```

注意：`android/local.properties` 与 `ios/Flutter/Generated.xcconfig` 不在包内，`flutter pub get` 或首次构建会自动生成；iOS 还需要 `cd ios && pod install`。
