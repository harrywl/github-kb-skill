#!/bin/sh
# 抓取 gh CLI 官方手册全部命令页并转成纯文本，用于核对本技能的每一条断言。
#
# 用法: sh scripts/fetch-official-docs.sh [输出目录]
#   默认输出目录: ./gh-docs
#
# 产物:
#   gh-docs/cmd_list.txt        全部命令名（213 个左右）
#   gh-docs/pages/<cmd>.html     原始 HTML
#   gh-docs/text/<cmd>.txt       剥掉标签后的正文（SKILL.md 的事实来源）
#
# 注意: 官方手册站点由 cli/cli 的 trunk 分支生成，内容可能略新于你本机装的 gh 版本。

set -e
OUT="${1:-gh-docs}"
BASE="https://cli.github.com/manual"

command -v curl >/dev/null 2>&1 || { echo "需要 curl" >&2; exit 1; }

mkdir -p "$OUT/pages" "$OUT/text"

echo "→ 拉取命令列表"
curl -sL --max-time 30 "$BASE/" \
  | grep -o 'gh_[a-z_0-9]\+' \
  | sort -u > "$OUT/cmd_list.txt"
echo "  $(wc -l < "$OUT/cmd_list.txt") 个命令"

echo "→ 下载页面（并发 8）"
cat "$OUT/cmd_list.txt" | xargs -P 8 -I{} sh -c \
  "curl -sL --max-time 30 -o '$OUT/pages/{}.html' '$BASE/{}.html'"

echo "→ 提取正文"
for f in "$OUT"/pages/*.html; do
  b=$(basename "$f" .html)
  sed -n '/<main id="main"/,/<\/main>/p' "$f" \
    | sed -e 's/<[^>]*>/\n/g' \
          -e 's/&quot;/"/g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&#39;/'"'"'/g' \
          -e 's/&nbsp;/ /g; s/&rarr;/->/g; s/&#34;/"/g; s/&#x2F;/\//g; s/&#43;/+/g' \
    | sed -e 's/^[[:space:]]*//' -e '/^$/d' > "$OUT/text/$b.txt"
done
echo "  $(ls "$OUT/text" | wc -l) 篇纯文本"

cat <<'EOF'

核对提示：
  * 查某命令的 flag：  grep -A2 '^--your-flag'  gh-docs/text/gh_xxx.txt
  * 查某命令的 JSON 字段：查 "JSON FIELDS" 段
  * 查 flag 取值：      紧跟 flag 下一行，如 {open|closed}
  * 查环境变量：        gh-docs/text/gh_help_environment.txt
  * 查全部命令树：      gh-docs/text/gh_help_reference.txt
EOF
