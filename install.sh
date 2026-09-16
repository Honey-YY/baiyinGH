#!/usr/bin/env bash
# web-access skill — 安装脚本
# 适用于 macOS / Linux / Windows Git Bash
#
# 用法:
#   bash install.sh                          安装到默认目录
#   bash install.sh --dest /path/to/skills   安装到自定义目录
#
# 环境变量:
#   WORKBUDDY_SKILLS_DIR   等同于 --dest
#
# 说明:
#   本仓库是「一个 skill 一个仓库」结构，脚本所在目录即技能本体，
#   安装过程就是把技能本体复制到 skills 目录下的 web-access/。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="web-access"
DEST_DIR="${WORKBUDDY_SKILLS_DIR:-$HOME/.workbuddy/skills}"

show_usage() {
  echo "web-access skill — 安装脚本"
  echo ""
  echo "用法:"
  echo "  bash install.sh                          安装到默认目录"
  echo "  bash install.sh --dest <目录>            安装到自定义目录"
  echo ""
  echo "默认目标目录: \$HOME/.workbuddy/skills"
  echo "安装后位置  : <目标目录>/web-access"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dest | -d) DEST_DIR="${2:-}"; shift 2 ;;
    --help | -h) show_usage; exit 0 ;;
    *) echo "未知参数: $1（用 --help 查看用法）" >&2; exit 1 ;;
  esac
done

if [ -z "$DEST_DIR" ]; then
  echo "错误：目标目录为空。" >&2
  exit 1
fi

TARGET="$DEST_DIR/$SKILL_NAME"

echo "=============================================="
echo " web-access skill — 安装"
echo "=============================================="
echo "技能源目录: $SCRIPT_DIR"
echo "目标目录  : $DEST_DIR"
echo "安装后位置: $TARGET"
echo ""

# 源必须是技能本体
if [ ! -f "$SCRIPT_DIR/SKILL.md" ]; then
  echo "错误：在脚本所在目录找不到 SKILL.md。" >&2
  echo "请确认在 web-access 仓库根目录运行本脚本。" >&2
  exit 1
fi

# 防呆：目标目录不能位于仓库内部，否则复制会自我递归
case "$TARGET" in
  "$SCRIPT_DIR"/*)
    echo "错误：目标目录不能位于仓库内部。" >&2
    exit 1
    ;;
esac

# 已经就是安装位置（例如直接 git clone 到了 skills 目录）
if [ -d "$TARGET" ] && [ "$SCRIPT_DIR" = "$(cd "$TARGET" && pwd)" ]; then
  echo "本目录已经是技能的安装位置，无需复制。"
  echo "请重启 AI 客户端（或新开一个会话）以加载技能。"
  exit 0
fi

if [ -d "$TARGET" ]; then
  echo "目标已存在，将覆盖: $TARGET"
  rm -rf "${TARGET:?}"
fi

mkdir -p "$TARGET"
cp -R "$SCRIPT_DIR/." "$TARGET/"

# 去掉仓库管道文件：它们与技能运行无关，留着会污染技能目录
rm -rf "$TARGET/.git" \
       "$TARGET/dist" \
       "$TARGET/tools" \
       "$TARGET/install.sh" \
       "$TARGET/install.ps1" \
       "$TARGET/package.json" \
       "$TARGET/.gitattributes" \
       "$TARGET/.gitignore" \
       "$TARGET/config.env"

echo ""
echo "安装完成: $TARGET"
echo ""
echo "完成。请重启 AI 客户端（或新开一个会话）以加载技能。"
echo "首次使用前，请阅读 $TARGET/INSTALL.md。"
