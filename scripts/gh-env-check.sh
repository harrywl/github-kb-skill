#!/bin/sh
# github-kb 环境自检：输出 KEY=VALUE 行，退出码 0 = 可用，1 = 有阻断项
# 用法: sh scripts/gh-env-check.sh    （在技能目录下执行）

blocked=0

# --- gh CLI ---
if command -v gh >/dev/null 2>&1; then
  gh_installed=yes
  gh_ver=$(gh --version 2>/dev/null | head -1)
else
  gh_installed=no
  gh_ver=""
  blocked=1
fi
echo "gh_installed=$gh_installed"
echo "gh_version=$gh_ver"
echo "gh_path=$(command -v gh 2>/dev/null)"

# --- 认证 ---
if [ -n "$GH_TOKEN" ] || [ -n "$GITHUB_TOKEN" ]; then
  echo "gh_token_present=yes"
else
  echo "gh_token_present=no"
fi

if [ "$gh_installed" = "yes" ]; then
  if gh api user --jq '.login' >/tmp/gh_check_login 2>/tmp/gh_check_err; then
    echo "gh_authed=yes"
    echo "gh_login=$(cat /tmp/gh_check_login)"
    echo "gh_token_valid=yes"
  else
    echo "gh_authed=no"
    echo "gh_login="
    echo "gh_token_valid=no"
    echo "gh_auth_error=$(head -c 200 /tmp/gh_check_err | tr '\n' ' ')"
    # 令牌无效不算硬阻断：公开 REST 查询走 scripts/gh-api.sh 匿名模式
    # 令牌一旦被更新，gh-setup-auth.sh 会把它注册进 gh 凭据库
  fi
  rm -f /tmp/gh_check_login /tmp/gh_check_err
fi

# --- 令牌有效性（不依赖 gh，用 curl 直验；有效则顺手注册进 gh 凭据库） ---
if [ -n "$GH_TOKEN" ] || [ -n "$GITHUB_TOKEN" ]; then
  tcode=$(curl -s -o /tmp/gh_tok_check -w '%{http_code}' --max-time 20 \
    -H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" https://api.github.com/user 2>/dev/null)
  if [ "$tcode" = "200" ]; then
    echo "token_api_valid=yes"
    echo "token_login=$(jq -r '.login // "?"' /tmp/gh_tok_check 2>/dev/null)"
    if [ "$gh_authed" != "yes" ] && [ "$gh_installed" = "yes" ]; then
      printf '%s' "${GH_TOKEN:-$GITHUB_TOKEN}" | env -u GH_TOKEN -u GITHUB_TOKEN timeout 60 gh auth login --hostname github.com --with-token >/dev/null 2>&1 \
        && echo "gh_auto_login=ok" || echo "gh_auto_login=failed"
    fi
  else
    echo "token_api_valid=no"
    echo "token_api_http_code=$tcode"
  fi
  rm -f /tmp/gh_tok_check
fi

# --- API 连通性 / 配额（curl，回退路径） ---
api_code=$(curl -s -o /tmp/gh_check_rate -w '%{http_code}' --max-time 15 https://api.github.com/rate_limit 2>/dev/null)
echo "api_http_code=$api_code"
if [ "$api_code" = "200" ]; then
  echo "api_reachable=yes"
  if command -v python3 >/dev/null 2>&1; then
    core=$(python3 -c "import json;d=json.load(open('/tmp/gh_check_rate'));print(d['resources']['core']['remaining'])" 2>/dev/null)
    climit=$(python3 -c "import json;d=json.load(open('/tmp/gh_check_rate'));print(d['resources']['core']['limit'])" 2>/dev/null)
    echo "rest_rate_remaining=$core"
    echo "rest_rate_limit=$climit"
  fi
else
  echo "api_reachable=no"
  blocked=1
fi
rm -f /tmp/gh_check_rate

# --- 代理 ---
echo "proxy=${HTTP_PROXY:-${http_proxy:-none}}"

# --- 依赖 ---
for t in python3 git curl jq; do
  if command -v "$t" >/dev/null 2>&1; then
    echo "has_$t=yes"
  else
    echo "has_$t=no"
  fi
done

# --- 本地知识库 ---
kb_root=""
for d in "$HOME/github-kb" /workspace/repos "$HOME/repos"; do
  if [ -n "$kb_root" ]; then break; fi
  if [ -d "$d" ]; then kb_root="$d"; fi
done
echo "kb_root=$kb_root"
if [ -n "$kb_root" ]; then
  echo "kb_repos_count=$(ls -1 "$kb_root" 2>/dev/null | wc -l | tr -d ' ')"
else
  echo "kb_repos_count=0"
fi

echo "blocked=$blocked"
[ "$blocked" = "0" ] && exit 0 || exit 1
