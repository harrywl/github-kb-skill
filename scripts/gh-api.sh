#!/bin/sh
# github-kb REST 回退脚本：curl 直连 api.github.com
# 令牌有效则用令牌（5000/小时），否则匿名（60/小时）
#
# 用法:
#   sh gh-api.sh <api-path> [query-string] [--jq 'expr'] [--method GET|POST] [--body 'json']
# 例:
#   sh gh-api.sh repos/cli/cli
#   sh gh-api.sh search/repositories "q=stars:>1000+language:go&per_page=5" --jq '.items[].full_name'
#   sh gh-api.sh search/issues "q=repo:cli/cli+state:closed&per_page=5" --jq '.items[] | "\(.number) \(.title)"'
#   sh gh-api.sh rate_limit --jq '.rate'

PATH_PART="$1"; shift
QUERY=""
JQ=""
METHOD="GET"
BODY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) JQ="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) if [ -z "$QUERY" ]; then QUERY="$1"; else QUERY="$QUERY $1"; fi; shift ;;
  esac
done

[ -z "$PATH_PART" ] && { echo "usage: gh-api.sh <api-path> [query] [--jq expr]" >&2; exit 2; }

URL="https://api.github.com/$PATH_PART"
[ -n "$QUERY" ] && URL="$URL?$QUERY"

# 令牌有效性探测：先试带令牌，401 则退回匿名
USE_TOKEN=0
TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
if [ -n "$TOKEN" ]; then
  probe=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -H "Authorization: Bearer $TOKEN" https://api.github.com/rate_limit)
  if [ "$probe" = "200" ]; then
    USE_TOKEN=1
  fi
fi

# 注意: 授权头必须用引号包住整个 "Authorization: Bearer <token>"，否则词分割会把 token 截掉
if [ "$USE_TOKEN" = "1" ]; then
  RESP=$(curl -s --max-time 30 -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Authorization: Bearer $TOKEN" \
    -X "$METHOD" ${BODY:+-d "$BODY"} "$URL")
else
  RESP=$(curl -s --max-time 30 -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -X "$METHOD" ${BODY:+-d "$BODY"} "$URL")
fi

if [ -n "$JQ" ]; then
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$RESP" | jq -r "$JQ"
  else
    echo "jq required for --jq (apk add jq / apt install jq / brew install jq)" >&2; exit 3
  fi
else
  printf '%s\n' "$RESP"
fi
