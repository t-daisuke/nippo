#!/bin/bash
# 세션 로그를 수집하는 스크립트
# 인수: 날짜 (YYYY-MM-DD) 또는 "yesterday" 또는 비어 있음 (오늘)
#
# - subagents 제외 (메인 세션만)
# - 사용자 메시지를 추출하여 출력
# - 수정 시간으로 사전 필터링하여 처리 속도 향상

set -e

# 대상 날짜 결정
if [ -n "$1" ]; then
  case "$1" in
    yesterday) TARGET_DATE=$(date -v-1d +%Y-%m-%d) ;;
    *)         TARGET_DATE="$1" ;;
  esac
else
  TARGET_DATE=$(date +%Y-%m-%d)
fi

echo "# 일일 보고서 데이터 - $TARGET_DATE"
echo ""

# 전날과 다음 날 계산 (수정 시간 필터용)
DATE_PREV=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" -v-1d +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")
DATE_NEXT=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" -v+1d +%Y-%m-%d 2>/dev/null || echo "$TARGET_DATE")

# 세션 로그 스캔 (subagents 제외)
find ~/.claude/projects -name "*.jsonl" -type f -not -path "*/subagents/*" 2>/dev/null | while read -r filepath; do
  # 1. 수정 시간으로 사전 필터링 (빠름)
  file_mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$filepath" 2>/dev/null) || continue

  if [ "$file_mtime" != "$TARGET_DATE" ] && [ "$file_mtime" != "$DATE_PREV" ] && [ "$file_mtime" != "$DATE_NEXT" ]; then
    continue
  fi

  # 2. 타임스탬프로 정확히 필터링 (첫 번째 사용자 메시지에서 가져옴)
  first_timestamp=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)

  if [ -z "$first_timestamp" ] || [ "$first_timestamp" = "null" ]; then
    continue
  fi

  utc_datetime="${first_timestamp%.*}+0000"
  session_date=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$utc_datetime" "+%Y-%m-%d" 2>/dev/null) || continue

  if [ "$session_date" = "$TARGET_DATE" ]; then
    # 프로젝트 이름 추출
    project=$(echo "$filepath" | sed 's|.*projects/||' | cut -d'/' -f1)

    # 첫 번째 사용자 메시지에서 메타 정보 가져오기
    first_user_line=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null)
    cwd=$(echo "$first_user_line" | jq -r '.cwd // "unknown"')
    branch=$(echo "$first_user_line" | jq -r '.gitBranch // ""')

    echo "## 세션: $project"
    echo "- 작업 디렉토리: $cwd"
    [ -n "$branch" ] && echo "- 브랜치: $branch"
    echo ""
    echo "### 사용자 메시지"

    # 사용자 메시지 추출 (빈 줄 제외)
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
