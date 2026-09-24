#!/usr/bin/env zsh
# find-vault.sh — 在本机自动定位 Obsidian 中“林林总总”目录
#
# 用法:
#   find-vault.sh             输出目标目录绝对路径到 stdout
#   find-vault.sh --rescan    忽略缓存重新扫描
#   find-vault.sh --create    目标目录不存在时自动创建
#
# 优先级:
#   1. 环境变量 LLZZ_DIR（显式覆盖）
#   2. 缓存文件 ~/.config/llzz/target-dir
#   3. Obsidian 注册的 vault（obsidian.json，按最近使用排序）
#   4. iCloud Obsidian 容器下的 vault
#   5. 常见本地目录下含 .obsidian 的 vault
#
# 找到含“林林总总”子目录的 vault 即返回；若所有 vault 都没有该子目录，
# 返回最近使用的 vault 下的“林林总总”路径（配合 --create 会自动创建）。

set -euo pipefail

TARGET_NAME="林林总总"
CACHE_FILE="${LLZZ_CACHE:-$HOME/.config/llzz/target-dir}"
RESCAN=0
CREATE=0

for arg in "$@"; do
  case "$arg" in
    --rescan) RESCAN=1 ;;
    --create) CREATE=1 ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

# 1. 显式覆盖
if [[ -n "${LLZZ_DIR:-}" ]]; then
  if [[ ! -d "$LLZZ_DIR" ]]; then
    echo "LLZZ_DIR 指向的目录不存在: $LLZZ_DIR" >&2
    exit 1
  fi
  echo "${LLZZ_DIR%/}"
  exit 0
fi

# 2. 缓存
if [[ $RESCAN -eq 0 && -f "$CACHE_FILE" ]]; then
  cached="$(head -1 "$CACHE_FILE")"
  if [[ -d "$cached" ]]; then
    echo "$cached"
    exit 0
  fi
  echo "缓存路径已失效，重新扫描: $cached" >&2
fi

# 3. 收集候选 vault（按优先级，去重）
typeset -a vaults

add_vault() {
  local p="${1%/}"
  [[ -d "$p" ]] || return 0
  [[ -d "$p/.obsidian" ]] || return 0
  local existing
  for existing in "${vaults[@]:-}"; do
    [[ "$existing" == "$p" ]] && return 0
  done
  vaults+=("$p")
}

# 3a. Obsidian 注册的 vault（按最近使用排序）
OBS_JSON="$HOME/Library/Application Support/obsidian/obsidian.json"
if [[ -f "$OBS_JSON" ]] && command -v python3 >/dev/null 2>&1; then
  while IFS= read -r p; do
    add_vault "$p"
  done < <(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    vaults = d.get("vaults", {})
    for v in sorted(vaults.values(), key=lambda x: x.get("ts", 0), reverse=True):
        print(v["path"])
except Exception:
    pass
' "$OBS_JSON" 2>/dev/null)
fi

# 3b. iCloud Obsidian 容器
for d in "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/"*(/N); do
  add_vault "$d"
done

# 3c. 常见本地目录（一层深度，含 .obsidian 才算 vault）
for base in "$HOME/Documents" "$HOME/Obsidian" "$HOME/Notes" "$HOME/笔记"; do
  [[ -d "$base" ]] || continue
  add_vault "$base"
  for d in "$base"/*(/N); do
    add_vault "$d"
  done
done

if [[ ${#vaults[@]} -eq 0 ]]; then
  echo "未找到任何 Obsidian vault（未发现 .obsidian 目录）" >&2
  echo "可用 LLZZ_DIR=<路径> 手动指定“$TARGET_NAME”目录" >&2
  exit 1
fi

echo "发现 ${#vaults[@]} 个 vault:" >&2
for v in "${vaults[@]}"; do
  echo "  - $v" >&2
done

# 4. 优先选择已有“林林总总”子目录的 vault
target=""
for v in "${vaults[@]}"; do
  if [[ -d "$v/$TARGET_NAME" ]]; then
    target="$v/$TARGET_NAME"
    break
  fi
done

# 5. 都没有 → 使用最近使用的 vault，目标目录待创建
if [[ -z "$target" ]]; then
  target="${vaults[1]}/$TARGET_NAME"
  echo "没有 vault 含“$TARGET_NAME”目录，将使用最近使用的 vault: $target" >&2
  if [[ $CREATE -eq 1 ]]; then
    mkdir -p "$target"
    echo "已创建目录: $target" >&2
  fi
fi

# 6. 写入缓存并输出
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$target" > "$CACHE_FILE"
echo "$target"
