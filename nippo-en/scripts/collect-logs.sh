#!/bin/bash
# Script to collect session logs
# Arguments: date (YYYY-MM-DD) or "yesterday" or empty (today)
#
# - Excludes subagents (main sessions only)
# - Extracts and outputs user messages
# - Pre-filters by modification time for faster processing

set -e

# Determine target date
if [ -n "$1" ]; then
  case "$1" in
    yesterday) TARGET_DATE=$(date -v-1d +%Y-%m-%d) ;;
    *)         TARGET_DATE="$1" ;;
  esac
else
  TARGET_DATE=$(date +%Y-%m-%d)
fi

echo "# Daily Report Data - $TARGET_DATE"
echo ""

# Calculate previous and next day for modification time filter
DATE_PREV=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" -v-1d +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")
DATE_NEXT=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" -v+1d +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")

# Scan session logs (excluding subagents)
find ~/.claude/projects -name "*.jsonl" -type f -not -path "*/subagents/*" 2>/dev/null | while read -r filepath; do
  # 1. Pre-filter by modification time (fast)
  file_mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$filepath" 2>/dev/null) || continue

  if [ "$file_mtime" != "$TARGET_DATE" ] && [ "$file_mtime" != "$DATE_PREV" ] && [ "$file_mtime" != "$DATE_NEXT" ]; then
    continue
  fi

  # 2. Filter accurately by timestamp (from first user message)
  first_timestamp=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)

  if [ -z "$first_timestamp" ] || [ "$first_timestamp" = "null" ]; then
    continue
  fi

  utc_datetime="${first_timestamp%.*}+0000"
  session_date=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$utc_datetime" "+%Y-%m-%d" 2>/dev/null) || continue

  if [ "$session_date" = "$TARGET_DATE" ]; then
    # Extract project name
    project=$(echo "$filepath" | sed 's|.*projects/||' | cut -d'/' -f1)

    # Get meta info from first user message
    first_user_line=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null)
    cwd=$(echo "$first_user_line" | jq -r '.cwd // "unknown"')
    branch=$(echo "$first_user_line" | jq -r '.gitBranch // ""')

    echo "## Session: $project"
    echo "- Working directory: $cwd"
    [ -n "$branch" ] && echo "- Branch: $branch"
    echo ""
    echo "### User Messages"

    # Extract user messages (excluding empty lines)
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
