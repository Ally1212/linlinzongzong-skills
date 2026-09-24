#!/usr/bin/env zsh
# find-vault.sh — 在本机自动定位 Obsidian vault 根目录（以“笔记地图”为锚点）
#
# 用法:
#   find-vault.sh           输出 vault 根目录绝对路径到 stdout
#   find-vault.sh --rescan  忽略缓存重新扫描
#
# 优先级:
#   1. 环境变量 LLZZ_VAULT（显式覆盖）
#   2. 缓存文件 ~/.config/llzz/vault-root
#   3. Obsidian 注册的 vault（obsidian.json，按最近使用排序）
#   4. iCloud Obsidian 容器下的 vault
#   5. 常见本地目录下含 .obsidian 的 vault
#
# 选择规则: 第一个含“笔记地图.md”的 vault 即为目标；
# 若所有 vault 都没有笔记地图，返回最近使用的 vault（由技能走初始化流程）。

set -euo pipefail

MAP_NAME="笔记地图.md"
CACHE_FILE="${LLZZ_CACHE:-$HOME/.config/llzz/vault-root}"
RESCAN=0

for arg in "$@"; do
  case "$arg" in
    --rescan) RESCAN=1 ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

# 1. 显式覆盖
if [[ -n "${LLZZ_VAULT:-}" ]]; then
  if [[ ! -d "$LLZZ_VAULT" ]]; then
    echo "LLZZ_VAULT 指向的目录不存在: $LLZZ_VAULT" >&2
    exit 1
  fi
  echo "${LLZZ_VAULT%/}"
  exit 0
fi

# 2. 缓存
if [[ $RESCAN -eq 0 && -f "$CACHE_FILE" ]]; then
  cached="$(head -1 "$CACHE_FILE")"
  if [[ -d "$cached" && -d "$cached/.obsidian" ]]; then
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
  echo "可用 LLZZ_VAULT=<路径> 手动指定 vault 根目录" >&2
  exit 1
fi

echo "发现 ${#vaults[@]} 个 vault:" >&2
for v in "${vaults[@]}"; do
  echo "  - $v" >&2
done

# 4. 优先选择含“笔记地图.md”的 vault
target=""
for v in "${vaults[@]}"; do
  if [[ -f "$v/$MAP_NAME" ]]; then
    target="$v"
    break
  fi
done

# 5. 都没有 → 使用最近使用的 vault（技能应走笔记地图初始化流程）
if [[ -z "$target" ]]; then
  target="${vaults[1]}"
  echo "没有 vault 含“$MAP_NAME”，使用最近使用的 vault（需初始化笔记地图）: $target" >&2
fi

# 6. 写入缓存并输出
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$target" > "$CACHE_FILE"
echo "$target"
