#!/usr/bin/env bash
# AI 技能库 — 一键安装脚本
# 适用于 macOS / Linux / Windows Git Bash
#
# 用法:
#   bash install.sh                      交互式选择
#   bash install.sh --all                安装全部技能
#   bash install.sh --skill web-access   安装指定技能
#   bash install.sh --dest /path/to/skills   自定义目标目录
#
# 环境变量:
#   WORKBUDDY_SKILLS_DIR   等同于 --dest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/skills"
DEST_DIR="${WORKBUDDY_SKILLS_DIR:-$HOME/.workbuddy/skills}"

INSTALL_ALL=0
SKILL_NAME=""

show_usage() {
  echo "AI 技能库 — 安装脚本"
  echo ""
  echo "用法:"
  echo "  bash install.sh                      交互式选择"
  echo "  bash install.sh --all                安装全部技能"
  echo "  bash install.sh --skill <名称>       安装指定技能"
  echo "  bash install.sh --dest <目录>        自定义目标目录"
  echo ""
  echo "默认目标目录: \$HOME/.workbuddy/skills"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --all | -a)   INSTALL_ALL=1; shift ;;
    --skill | -s) SKILL_NAME="${2:-}"; shift 2 ;;
    --dest | -d)  DEST_DIR="${2:-}"; shift 2 ;;
    --help | -h)  show_usage; exit 0 ;;
    *) echo "未知参数: $1（用 --help 查看用法）" >&2; exit 1 ;;
  esac
done

echo "=============================================="
echo " AI 技能库 — 安装"
echo "=============================================="
echo "源目录  : $SRC_DIR"
echo "目标目录: $DEST_DIR"
echo ""

if [ ! -d "$SRC_DIR" ]; then
  echo "错误：找不到 skills 目录。" >&2
  echo "请确认在仓库根目录运行本脚本。" >&2
  exit 1
fi

skills=()
while IFS= read -r entry; do
  [ -n "$entry" ] && skills+=("$entry")
done < <(ls -1 "$SRC_DIR" 2>/dev/null || true)

if [ "${#skills[@]}" -eq 0 ]; then
  echo "错误：skills 目录为空。" >&2
  exit 1
fi

targets=()

if [ -n "$SKILL_NAME" ]; then
  found=0
  for s in "${skills[@]}"; do
    if [ "$s" = "$SKILL_NAME" ]; then
      targets=("$s")
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "错误：找不到技能「$SKILL_NAME」。" >&2
    echo "可用技能：${skills[*]}" >&2
    exit 1
  fi
elif [ "$INSTALL_ALL" -eq 1 ]; then
  targets=("${skills[@]}")
else
  echo "可用技能："
  i=0
  for s in "${skills[@]}"; do
    i=$((i + 1))
    printf "  %d) %s\n" "$i" "$s"
  done
  echo "  a) 全部安装"
  echo ""

  printf "请选择（输入序号，或 a 全部）: "
  read -r choice

  if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
    targets=("${skills[@]}")
  elif printf '%s' "$choice" | grep -qE '^[0-9]+$' \
    && [ "$choice" -ge 1 ] \
    && [ "$choice" -le "${#skills[@]}" ]; then
    targets=("${skills[$((choice - 1))]}")
  else
    echo "无效选择，已退出。" >&2
    exit 1
  fi
fi

mkdir -p "$DEST_DIR"
echo ""

for s in "${targets[@]}"; do
  if [ -d "$DEST_DIR/$s" ]; then
    echo "  已存在，将覆盖: $s"
    rm -rf "${DEST_DIR:?}/$s"
  fi
  cp -R "$SRC_DIR/$s" "$DEST_DIR/$s"
  echo "  已安装: $s"
done

echo ""
echo "完成。请重启 WorkBuddy（或新开一个会话）以加载技能。"
echo "首次使用前，请阅读对应技能目录下的 INSTALL.md。"
