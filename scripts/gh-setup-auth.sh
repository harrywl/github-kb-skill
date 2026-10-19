#!/bin/sh
# 用环境变量里的 GH_TOKEN 给 gh 登录，并把凭据落到 ~/.config/gh/hosts.yml。
# 令牌有效则成功（后续 gh 子命令全可用）；无效则打印 GitHub 的原始报错并退出 1。
#
# 用法: sh scripts/gh-setup-auth.sh    （在技能目录下执行）
# 令牌更新后重跑本脚本即可立即生效。

TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
if [ -z "$TOKEN" ]; then
  echo "error=GH_TOKEN 未设置" >&2
  echo "hint=https://github.com/settings/tokens" >&2
  exit 1
fi

# 先直接打 API 验明令牌，避免把坏令牌写进 hosts.yml
code=$(curl -s -o /tmp/gh_setup_user -w '%{http_code}' --max-time 20 \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  https://api.github.com/user)
if [ "$code" != "200" ]; then
  echo "error=令牌被 GitHub 拒绝 (HTTP $code)" >&2
  echo "body=$(head -c 300 /tmp/gh_setup_user | tr '\n' ' ')" >&2
  rm -f /tmp/gh_setup_user
  exit 1
fi
login=$(jq -r '.login // "?"' /tmp/gh_setup_user 2>/dev/null)
rm -f /tmp/gh_setup_user
echo "token_valid=yes"
echo "login=$login"

# 写入 gh 凭据库（必须清掉 GH_TOKEN，否则 gh 会拒绝存凭据：
# "The value of the GH_TOKEN environment variable is being used for authentication"）
printf '%s' "$TOKEN" | env -u GH_TOKEN -u GITHUB_TOKEN timeout 60 gh auth login --hostname github.com --with-token >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "gh_login=ok"
  gh auth status 2>&1 | sed 's/^/gh_status: /'
  exit 0
fi
echo "gh_login=failed（令牌有效但 gh 登录失败，看上面 gh_status）" >&2
exit 1
