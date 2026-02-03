#!/bin/bash
# セッションログを収集するスクリプト
# 引数: 日付 (YYYY-MM-DD) または "yesterday" または 空（今日）
#
# - subagentsは除外（メインセッションのみ）
# - ユーザーメッセージを抽出して出力
# - 更新日時で事前フィルタリングして高速化

set -e

# OS判定
is_macos() { [[ "$(uname)" == "Darwin" ]]; }

# 日付計算のラッパー
date_calc() {
  local base_date="$1" offset="$2" # offset: -1, +1 など
  if is_macos; then
    date -j -f "%Y-%m-%d" "$base_date" -v"${offset}d" +%Y-%m-%d 2>/dev/null || echo "$base_date"
  else
    date -d "$base_date ${offset} day" +%Y-%m-%d 2>/dev/null || echo "$base_date"
  fi
}

# ファイルの更新日時を取得
file_mtime() {
  if is_macos; then
    stat -f "%Sm" -t "%Y-%m-%d" "$1" 2>/dev/null
  else
    stat -c "%Y" "$1" 2>/dev/null | cut -c1-10 | xargs -I{} date -d "@{}" +%Y-%m-%d 2>/dev/null
  fi
}

# UTCタイムスタンプをローカル日付に変換
timestamp_to_date() {
  local ts="$1"
  if is_macos; then
    local utc_datetime="${ts%.*}+0000"
    date -j -f "%Y-%m-%dT%H:%M:%S%z" "$utc_datetime" "+%Y-%m-%d" 2>/dev/null
  else
    date -d "$ts" "+%Y-%m-%d" 2>/dev/null
  fi
}

# 対象日付を決定
if [ -n "$1" ]; then
  case "$1" in
    yesterday) TARGET_DATE=$(date_calc "$(date +%Y-%m-%d)" -1) ;;
    *)         TARGET_DATE="$1" ;;
  esac
else
  TARGET_DATE=$(date +%Y-%m-%d)
fi

echo "# 日報データ - $TARGET_DATE"
echo ""

# 対象日の前日・当日・翌日を計算（更新日時フィルタ用）
DATE_PREV=$(date_calc "$TARGET_DATE" -1)
DATE_NEXT=$(date_calc "$TARGET_DATE" +1)

# セッションログを走査（subagentsは除外）
find ~/.claude/projects -name "*.jsonl" -type f -not -path "*/subagents/*" 2>/dev/null | while read -r filepath; do
  # 1. 更新日時で事前フィルタリング（高速）
  file_mtime=$(file_mtime "$filepath") || continue

  if [ "$file_mtime" != "$TARGET_DATE" ] && [ "$file_mtime" != "$DATE_PREV" ] && [ "$file_mtime" != "$DATE_NEXT" ]; then
    continue
  fi

  # 2. タイムスタンプで正確にフィルタリング（最初のuserメッセージから取得）
  first_timestamp=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)

  if [ -z "$first_timestamp" ] || [ "$first_timestamp" = "null" ]; then
    continue
  fi

  session_date=$(timestamp_to_date "$first_timestamp") || continue

  if [ "$session_date" = "$TARGET_DATE" ]; then
    # プロジェクト名を抽出
    project=$(echo "$filepath" | sed 's|.*projects/||' | cut -d'/' -f1)

    # メタ情報を最初のuserメッセージから取得
    first_user_line=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null)
    cwd=$(echo "$first_user_line" | jq -r '.cwd // "unknown"')
    branch=$(echo "$first_user_line" | jq -r '.gitBranch // ""')

    echo "## セッション: $project"
    echo "- 作業ディレクトリ: $cwd"
    [ -n "$branch" ] && echo "- ブランチ: $branch"
    echo ""
    echo "### ユーザーメッセージ"

    # ユーザーメッセージを抽出（空行を除外）
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
