#!/usr/bin/env bash
# 把「好好记账」App 的全部源码与必要运行资产打包成一个 zip。
#
# 打包范围（相对工程根目录）：
#   lib/ test/ assets/ android/ ios/ server/ third_party/ scripts/ docs/ +
#   pubspec.yaml pubspec.lock analysis_options.yaml .gitignore .metadata
#   README.md 与根目录的 *.md 说明文档
#
# 明确排除（可随时重装重建的内容，不入包）：
#   build/ .dart_tool/ .git/ .idea/ dist/（APK 输出） *.iml
#   android/{.gradle,.kotlin,build,local.properties,app/build}
#   ios/{Pods,.symlinks,Podfile.lock,Flutter/Generated.xcconfig,Flutter/ephemeral}
#   server/{node_modules,dist,data}          # 依赖、编译产物、运行时 sqlite
#   docs/qa/                                 # QA 截图归档，约 46MB，不属于源码
#   dsh-patches/ strategies/ haohaojizhangœ/ 未命名文件夹/   # 与本 App 无关
#   *.apk *.zip *.log .DS_Store
#
# 用法：
#   ./scripts/package_source.sh                     # 生成到工程根目录
#   ./scripts/package_source.sh --out ~/Desktop     # 指定输出目录
#   ./scripts/package_source.sh --with-qa-docs      # 额外包含 docs/qa 截图归档
#   ./scripts/package_source.sh --list              # 只列出将被打包的文件，不生成 zip

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 中文文件名必须按 UTF-8 处理：macOS 默认 locale 为 C 时，
# Info-ZIP / ditto 会写出无 UTF-8 标志位的双重编码文件名。
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"

OUT_DIR="$PROJECT_DIR"
WITH_QA_DOCS=0
LIST_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT_DIR="${2:?--out 需要一个目录参数}"
      shift 2
      ;;
    --with-qa-docs)
      WITH_QA_DOCS=1
      shift
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "未知参数：$1（用 --help 查看用法）" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$PROJECT_DIR/pubspec.yaml" ]]; then
  echo "未找到 $PROJECT_DIR/pubspec.yaml，请在记账工程内运行本脚本。" >&2
  exit 1
fi
if ! command -v rsync >/dev/null 2>&1; then
  echo "缺少 rsync，无法收集源码。" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "缺少 python3，无法生成 UTF-8 文件名正确的 zip。" >&2
  exit 1
fi

STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jizhang_pack.XXXXXX")"
STAGE="$STAGE_ROOT/jizhang_app"
mkdir -p "$STAGE"
cleanup() { rm -rf "$STAGE_ROOT"; }
trap cleanup EXIT

EXCLUDES=(
  --exclude='.DS_Store'
  --exclude='/build/'
  --exclude='/.dart_tool/'
  --exclude='/.git/'
  --exclude='/.idea/'
  --exclude='/dist/'
  --exclude='/.flutter-plugins-dependencies'
  --exclude='*.iml'
  --exclude='/android/.gradle/'
  --exclude='/android/.kotlin/'
  --exclude='/android/build/'
  --exclude='/android/local.properties'
  --exclude='/android/app/build/'
  --exclude='/android/app/debug/'
  --exclude='/android/app/profile/'
  --exclude='/android/app/release/'
  --exclude='/ios/Pods/'
  --exclude='/ios/.symlinks/'
  --exclude='/ios/Podfile.lock'
  --exclude='/ios/Flutter/Generated.xcconfig'
  --exclude='/ios/Flutter/flutter_export_environment.sh'
  --exclude='/ios/Flutter/ephemeral/'
  --exclude='/ios/Flutter/.last_build_id'
  --exclude='/server/node_modules/'
  --exclude='/server/dist/'
  --exclude='/server/data/'
  --exclude='/dsh-patches/'
  --exclude='/strategies/'
  --exclude='/haohaojizhangœ/'
  --exclude='/未命名文件夹/'
  --exclude='*.apk'
  --exclude='*.zip'
  --exclude='*.log'
)
if [[ "$WITH_QA_DOCS" -eq 0 ]]; then
  EXCLUDES+=(--exclude='/docs/qa/')
fi

rsync -aH "${EXCLUDES[@]}" "$PROJECT_DIR"/ "$STAGE"/

FILE_COUNT="$(find "$STAGE" -type f | wc -l | tr -d ' ')"
if [[ "$FILE_COUNT" -eq 0 ]]; then
  echo "收集结果为空，打包中止。" >&2
  exit 1
fi

if [[ "$LIST_ONLY" -eq 1 ]]; then
  echo "将打包 $FILE_COUNT 个文件："
  (cd "$STAGE" && find . -type f | sed 's|^\./||' | sort)
  exit 0
fi

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M)"
OUT_ZIP="$OUT_DIR/jizhang_app_source_${STAMP}.zip"
rm -f "$OUT_ZIP"

# 注意：必须重定向 stdin。heredoc 占用的脚本 stdin 可能是外层管道，
# 若 python 继承并读走它，就会吞掉本脚本后续行，导致后面变量未定义。
python3 - "$STAGE" "$OUT_ZIP" < /dev/null <<'PY'
import os
import sys
import time
import zipfile

stage, out_zip = sys.argv[1], sys.argv[2]
root_name = os.path.basename(stage.rstrip(os.sep))
written = 0

with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for dirpath, dirnames, filenames in os.walk(stage):
        dirnames.sort()
        filenames.sort()
        rel = os.path.relpath(dirpath, stage)
        arc_dir = root_name if rel == '.' else os.path.join(root_name, rel)
        if rel != '.' and not filenames and not dirnames:
            info = zipfile.ZipInfo(arc_dir.replace(os.sep, '/') + '/')
            info.external_attr = (0o40755 << 16) | 0x10
            info.date_time = time.localtime(os.path.getmtime(dirpath))[:6]
            z.writestr(info, b'')
        for name in filenames:
            full = os.path.join(dirpath, name)
            arc = os.path.join(arc_dir, name).replace(os.sep, '/')
            st = os.lstat(full)
            info = zipfile.ZipInfo(arc)
            info.date_time = time.localtime(st.st_mtime)[:6]
            info.external_attr = (st.st_mode & 0xFFFF) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(full, 'rb') as fh:
                z.writestr(info, fh.read())
            written += 1

print(f'已写入 {written} 个文件')
PY

SIZE="$(du -h "$OUT_ZIP" | cut -f1)"
echo "打包完成：$OUT_ZIP"
echo "文件数：${FILE_COUNT}，大小：${SIZE}"
echo "解压：unzip \"$OUT_ZIP\"   # 解压后目录为 jizhang_app/"
