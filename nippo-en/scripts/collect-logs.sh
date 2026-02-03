#!/bin/bash
# Script to collect session logs
# Arguments: date (YYYY-MM-DD) or "yesterday" or empty (today)
#
# - Excludes subagents (main sessions only)
# - Extracts and outputs user messages
# - Pre-filters by modification time for faster processing

set -e

# OS detection
is_macos() { [[ "$(uname)" == "Darwin" ]]; }

# Date calculation wrapper
date_calc() {
  local base_date="$1" offset="$2" # offset: -1, +1, etc.
  if is_macos; then
    date -j -f "%Y-%m-%d" "$base_date" -v"${offset}d" +%Y-%m-%d 2>/dev/null || echo "$base_date"
  else
    date -d "$base_date ${offset} day" +%Y-%m-%d 2>/dev/null || echo "$base_date"
  fi
}

# Get file modification time
file_mtime() {
  if is_macos; then
    stat -f "%Sm" -t "%Y-%m-%d" "$1" 2>/dev/null
  else
    stat -c "%Y" "$1" 2>/dev/null | cut -c1-10 | xargs -I{} date -d "@{}" +%Y-%m-%d 2>/dev/null
  fi
}

# Convert UTC timestamp to local date
timestamp_to_date() {
  local ts="$1"
  if is_macos; then
    local utc_datetime="${ts%.*}+0000"
    date -j -f "%Y-%m-%dT%H:%M:%S%z" "$utc_datetime" "+%Y-%m-%d" 2>/dev/null
  else
    date -d "$ts" "+%Y-%m-%d" 2>/dev/null
  fi
}

# Determine target date
if [ -n "$1" ]; then
  case "$1" in
    yesterday) TARGET_DATE=$(date_calc "$(date +%Y-%m-%d)" -1) ;;
    *)         TARGET_DATE="$1" ;;
  esac
else
  TARGET_DATE=$(date +%Y-%m-%d)
fi

echo "# Daily Report Data - $TARGET_DATE"
echo ""

# Calculate previous and next day for modification time filter
DATE_PREV=$(date_calc "$TARGET_DATE" -1)
DATE_NEXT=$(date_calc "$TARGET_DATE" +1)

# Scan session logs (excluding subagents)
find ~/.claude/projects -name "*.jsonl" -type f -not -path "*/subagents/*" 2>/dev/null | while read -r filepath; do
  # 1. Pre-filter by modification time (fast)
  file_mtime=$(file_mtime "$filepath") || continue

  if [ "$file_mtime" != "$TARGET_DATE" ] && [ "$file_mtime" != "$DATE_PREV" ] && [ "$file_mtime" != "$DATE_NEXT" ]; then
    continue
  fi

  # 2. Filter accurately by timestamp (from first user message)
  first_timestamp=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)

  if [ -z "$first_timestamp" ] || [ "$first_timestamp" = "null" ]; then
    continue
  fi

  session_date=$(timestamp_to_date "$first_timestamp") || continue

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
