#!/bin/bash
# 收集会话日志的脚本
# 参数: 日期 (YYYY-MM-DD) 或 "yesterday" 或 空（今天）
#
# - 排除subagents（仅主会话）
# - 提取并输出用户消息
# - 通过修改时间预过滤以加快处理速度

set -e

# 确定目标日期
if [ -n "$1" ]; then
  case "$1" in
    yesterday) TARGET_DATE=$(date -v-1d +%Y-%m-%d) ;;
    *)         TARGET_DATE="$1" ;;
  esac
else
  TARGET_DATE=$(date +%Y-%m-%d)
fi

echo "# 日报数据 - $TARGET_DATE"
echo ""

# 计算前一天和后一天（用于修改时间过滤）
DATE_PREV=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" -v-1d +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")
DATE_NEXT=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" -v+1d +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")

# 扫描会话日志（排除subagents）
find ~/.claude/projects -name "*.jsonl" -type f -not -path "*/subagents/*" 2>/dev/null | while read -r filepath; do
  # 1. 通过修改时间预过滤（快速）
  file_mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$filepath" 2>/dev/null) || continue

  if [ "$file_mtime" != "$TARGET_DATE" ] && [ "$file_mtime" != "$DATE_PREV" ] && [ "$file_mtime" != "$DATE_NEXT" ]; then
    continue
  fi

  # 2. 通过时间戳精确过滤（从第一条用户消息获取）
  first_timestamp=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)

  if [ -z "$first_timestamp" ] || [ "$first_timestamp" = "null" ]; then
    continue
  fi

  utc_datetime="${first_timestamp%.*}+0000"
  session_date=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$utc_datetime" "+%Y-%m-%d" 2>/dev/null) || continue

  if [ "$session_date" = "$TARGET_DATE" ]; then
    # 提取项目名称
    project=$(echo "$filepath" | sed 's|.*projects/||' | cut -d'/' -f1)

    # 从第一条用户消息获取元信息
    first_user_line=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null)
    cwd=$(echo "$first_user_line" | jq -r '.cwd // "unknown"')
    branch=$(echo "$first_user_line" | jq -r '.gitBranch // ""')

    echo "## 会话: $project"
    echo "- 工作目录: $cwd"
    [ -n "$branch" ] && echo "- 分支: $branch"
    echo ""
    echo "### 用户消息"

    # 提取用户消息（排除空行）
    grep '"type":"user"' "$filepath" 2>/dev/null | jq -r '
      if .message.content | type == "string" then
        .message.content | split("\n")[0][:200]
      else
        ((.message.content[] | select(.type == "text") | .text | split("\n")[0][:200]) // "")
      end
    ' 2>/dev/null | grep -v '^$' | sed 's/^/- /' | head -20

    echo ""
  fi
done
