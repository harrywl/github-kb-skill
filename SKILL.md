---
name: github-kb
description: 通过 gh CLI 实时检索 GitHub 的仓库、Issue、Pull Request、代码与提交记录，并查询本地知识库目录（~/github-kb 或 /workspace/repos）中的克隆仓库。当用户需要查找开源项目、根据报错信息排查 Issue、参考他人代码实现、追踪提交历史、评估仓库健康度，或询问本地仓库知识库时使用。
---

# GitHub 知识库检索（gh CLI）

用 `gh` 实时取 GitHub 真数据。涉及代码库、报错、项目对比的问题，**先跑命令再回答**，禁止凭记忆推断；结论附来源 URL。

## 0. 环境状态

| 项 | 值 |
|---|---|
| gh | 2.102.0（`gh --version` 可确认）|
| 认证 | ✅ 已认证（classic PAT 走环境变量 `GH_TOKEN`；凭据在 `~/.config/gh/hosts.yml`）|
| 配额 | core 5000/小时；**code search 独立 10 次/分钟** |
| 依赖 | jq / python3 / git / curl；代理若已配好（常见 `http://127.0.0.1:7890`）就别改 |

每会话首次使用跑一次自检：

```bash
sh scripts/gh-env-check.sh    # 在技能目录下执行；KEY=VALUE 输出，exit 0 可用 / 1 有阻断
```

关键键：`gh_version` `gh_authed` `gh_login` `token_api_valid` `api_reachable` `rest_rate_remaining` `kb_root` `blocked`。通过后不必重复跑，也别做版本升级。

**认证口径**（完整环境变量表见 `gh help environment`）：官方明确**环境变量令牌最适合 headless/自动化**（本机走的就是这条）；`GH_TOKEN`/`GITHUB_TOKEN` **优先于已存凭据**；`GH_HOST` 指定主机；`GH_REPO=owner/repo` 在非 clone 目录指定仓库；`GH_ENTERPRISE_TOKEN` 用于 GHE；`GH_PROMPT_DISABLED=1` 禁交互提示（也可用 `gh config set prompt disabled`，更持久）；`GH_CONFIG_DIR` 改配置目录；`GH_DEBUG=api` 打印 HTTP 细节（排查 401 神器）。官方验活用 `gh auth status --active`（认证有问题时 exit 1，加 `--json hosts` 恒 exit 0，别用 `--json` 判断成败）。`gh auth login --with-token` 只吃 classic PAT（最小 scope `repo,read:org,gist`），fine-grained PAT 官方建议直接设 `GH_TOKEN`；补权限用 `gh auth refresh -s <scope>`。

**令牌掉了怎么办**（令牌失效 → gh 全部子命令 401，不回退匿名）：

1. 在 [GitHub PAT 设置页](https://github.com/settings/tokens) 生成新令牌，把值写进环境变量 `GH_TOKEN`（不要把 token 贴在聊天/工单里）；
2. `sh scripts/gh-setup-auth.sh` —— curl 直验后写 hosts.yml，即刻生效、无需重启 App；
3. 临时兜底 `sh scripts/gh-api.sh <api-path> [query] [--jq expr]` —— curl 直连，令牌有效则用、否则匿名 60/小时，只读公开数据。

## 1. 本地知识库

探测顺序：`~/github-kb` → `/workspace/repos` → `~/repos`。用 `ls` 列出，别猜内容。

进入 clone 目录后 gh 自动解析 remote，可省略 `--repo`（`gh repo view`、`gh pr status` 直接生效）；远端地址用 `git -C <path> remote -v`。

## 2. 意图 → 命令

| 意图 | 命令 |
|---|---|
| 找库/找工具 | `gh search repos` |
| 报错排查 | `gh search issues`（优先 `--state closed`）|
| 看功能怎么实现 | `gh search prs` + `gh search code` |
| 找 API/配置示例 | `gh search code` |
| 改动何时引入 | `gh search commits` |
| 仓库详情/健康度 | `gh repo view --json` |
| 读具体 issue/PR | `gh issue view` / `gh pr view` / `gh pr diff` |
| 发版与 CI | `gh release list/view`、`gh run list/view`、`gh workflow list` |
| 复杂聚合查询 | `gh api`（REST/GraphQL）|
| 找/装 Agent 技能 | `gh skill search` / `gh skill install` |

相互独立的搜索可在同一轮并行执行。

## 3. 搜索仓库

```bash
gh search repos "claude code skill" --sort stars --limit 3 \
  --json fullName,stargazersCount,description \
  --jq '.[] | "\(.fullName) ★\(.stargazersCount) \(.description)"'

# query 内置限定符与 flag 等效，可混用
gh search repos "mcp server language:python stars:>100 pushed:>2026-01-01" --limit 5
gh search repos "mcp in:name,description" --limit 2        # 限定名称/简介/README
```

flag：`--language` `--stars ">1000"` `--forks` `--topic` `--owner` `--license` `--archived {true|false}` `--created` `--updated` `--size` `--visibility` `--match {name|description|readme}` `--include-forks {false|true|only}` `--sort {stars|forks|updated|help-wanted-issues}` `--order {asc|desc}` `-L/--limit` `--help-wanted-issues`

字段：`fullName` `description` `stargazersCount` `forksCount` `language` `updatedAt` `pushedAt` `url` `owner` `isFork` `isPrivate` `visibility` 等（与 §7 的 `repo view` 命名不同：这里 `stargazersCount` 复数、那里 `stargazerCount` 单数）

> **查字段名不用背**：任何命令把 `--json` 的字段参数**留空**，gh 会列出该命令全部合法字段名（如 `gh search repos x --json`）。官方字段名随版本变动，**以这个输出为准**。该用法**退出码为 1**（用法提示，非执行失败）。

## 4. 搜索 Issue（排雷）

```bash
gh search issues "rate limit exceeded" --state closed --limit 2 --json title,url --jq '.[].title'
gh search issues "rate limit errors" --repo cli/cli --search-type hybrid --limit 3 --json number,title,url --jq '.[] | "#\(.number) \(.title)"'
gh search issues "deployment error" --label bug --author octocat --comments ">5" --limit 5
gh search issues --state closed --limit 2 --json title --jq '.[].title' -- "deployment error -label:wontfix"
```

flag（issues 与 prs 通用）：`--state {open|closed}` `--repo/-R` `--owner` `--label` `--author` `--assignee` `--commenter` `--mentions` `--involves` `--comments N` `--interactions N` `--reactions` `--created` `--updated` `--closed` `--locked` `--match {title|body|comments}` `--visibility` `--archived` `--language` `--app` `--milestone` `--no-assignee` `--no-label` `--team-mentions` `--project`
issues 专有：`--include-prs` `--search-type {lexical|semantic|hybrid}`

优先 `closed`；命中后用 `gh issue view <n> --repo <owner/repo> --json number,title,body,state,labels,author,comments` 读详情（排雷要看的正是 `body`；`gh search issues` 侧只有 `commentsCount`，没有 `comments`）。

## 5. 搜索 Pull Request

```bash
gh search prs "memory leak" --merged --limit 2 --json title,url --jq '.[].title'
gh search prs "wip" --draft --limit 2 --json title --jq '.[].title'
```

prs 专有 flag：`--merged` `--draft` `--review {none|required|approved|changes_requested}` `--review-requested` `--reviewed-by` `--checks {pending|success|failure}` `--merged-at` `--base` `--head`

> `gh search prs` 无 `--search-type`、无 `--state merged`（合并用 `--merged`）；搜索**默认覆盖全 GitHub**，务必用 `--repo owner/repo` 收窄。想看合并时间得用 `gh pr view`（search 侧没有 `mergedAt`）。

读取：`gh pr view <n> --json number,title,state,isDraft,reviews` / `gh pr diff <n>` / `gh pr checks <n>` / `gh pr list --state open --limit 10 --json number,title,isDraft`

## 6. 搜索代码与提交

```bash
gh search code "func main" --repo cli/cli --extension go --limit 2 --json path --jq '.[].path'
# code flag: --repo/-R --extension --filename --language --match {file|path} --owner --size（需认证）
# 取正文：search code 给 path/sha，再 gh api repos/{owner}/{repo}/contents/{path}
#   （textMatches 字段合法但 gh search code 通常返回空数组，别指望它给片段）；code search 独立配额 10 次/分钟

gh search commits "rate limit" --repo cli/cli --limit 2 \
  --json commit,author --jq '.[] | .commit.message | split("\n")[0]'
# commits 的 --json 共 8 个字段：author commit committer id parents repository sha url
# flag: --author --committer --author-name --author-email --committer-name --committer-email
#   --author-date --committer-date --hash --parent --merge --tree --owner --visibility
#   --sort {author-date|committer-date} --order
```

## 7. 仓库详情与健康度

```bash
gh repo view cli/cli --json description,stargazerCount,forkCount,pushedAt,primaryLanguage,latestRelease \
  --jq '"\(.description) ★\(.stargazerCount) ⑂\(.forkCount) \(.primaryLanguage.name)"'
gh browse -n --repo cli/cli      # 只输出 URL，不开浏览器
gh repo list --limit 3
```

字段：`description` `stargazerCount` `forkCount` `createdAt` `pushedAt` `updatedAt` `primaryLanguage` `latestRelease` `licenseInfo` `isArchived` `isFork` `defaultBranchRef` `url` 等（默认分支是 **`defaultBranchRef`** 不是 `defaultBranch`）

## 8. Issue / Release / CI 读取

```bash
gh issue list --repo cli/cli --state open --limit 5 --json number,title --jq '.[] | "#\(.number) \(.title)"'
gh release list --repo cli/cli --limit 3 --exclude-drafts
gh workflow list --repo cli/cli --all
gh run list --repo cli/cli --limit 5 --status success
gh run view <run-id> --repo cli/cli --log-failed
gh pr diff <n> --repo cli/cli --name-only     # 只列改了哪些文件
gh pr diff <n> --repo cli/cli --patch          # 补丁格式，可 pipe
gh pr checks <n> --repo cli/cli --json name,state,bucket --watch   # bucket: pass/fail/pending/skipping/cancel
```

常用 flag：
- `issue list --search/--label/--type/--mention/--milestone`（`--search` 的 `OR`/`AND`/括号要作为**独立参数**传，不能塞进一个引号字符串）
- `release list --exclude-drafts/--exclude-pre-releases`；`workflow list --all`
- `run list --status{queued|completed|in_progress|success|failure|cancelled|skipped|timed_out|...} --event --branch --workflow --user`
- `run view --log/--log-failed/--job/--attempt/--exit-status`
- `pr checks --watch/--fail-fast/--required`；`pr diff --name-only/--patch/--exclude <glob>`（看改动最常用）

`gh pr checks` 额外退出码 **8 = checks 仍在 pending**，适合写进轮询脚本。

在 clone 目录内上述命令均可省略 `--repo`。

> `gh issue list --search` 限**单个仓库**内过滤（默认当前仓库），`gh search issues` 走搜索 API 可**跨仓库**，两者都支持高级搜索语法。跨仓库找同类问题用后者，查本仓库关联 issue 用前者。

## 9. 发现与安装 Agent 技能（gh skill，2.102.0 新增）

```bash
gh skill search "github" --limit 5        # 用 Code Search API 找公开仓库里的 SKILL.md，按相关度+★排
gh skill install owner/repo --dir <skills-dir>             # 装到自定义目录（覆盖 --agent/--scope）
gh skill install owner/repo --agent claude-code --scope user
gh skill list / gh skill update / gh skill publish
```

`--agent` 值含 github-copilot / claude-code / cursor / codex / gemini-cli / opencode / universal 等；装到某个 agent 的技能目录用 `--dir <skills-dir>` 即可。`--scope` 为 `project|user`，`--pin` 锁版本，`--all` 免交互全装。

其它值得记住：`gh status`（跨仓库工作台：指派/待审/@我）、`gh issue status`、`gh ruleset check`（分支保护，评估健康度）、`gh label list`、`gh repo license view <spdx>`、`gh cache list`、`gh release verify`（产物验签）、`gh attestation verify`（构件来源）、`gh pr revert`、`gh issue develop`。

## 10. gh api（REST / GraphQL）

```bash
gh api repos/cli/cli --jq '.full_name + " " + (.stargazers_count|tostring)'
gh api "search/repositories?q=language:python+topic:mcp&per_page=2" --jq '.items[] | "\(.full_name) ★\(.stargazers_count)"'
gh api --paginate repos/cli/cli/labels --jq '.[].name'      # 自动翻页
gh api rate_limit --jq '.rate | "remaining=\(.remaining)/\(.limit)"'
gh api graphql -F owner=cli -F name=cli \
  -f query='query($owner:String!,$name:String!){ repository(owner:$owner,name:$name){ diskUsage } }' \
  --jq '.data.repository.diskUsage'
```

`-f`/`--raw-field` 传字符串，`-F`/`--field` 传数字/布尔/变量（`-F@file` 读文件、`-F@-` 读 stdin）。`{owner}` `{repo}` `{branch}` 占位符靠 git 探测从**当前目录**的仓库展开，不在 clone 内会报 `not a git repository` → 直接写 `owner/repo`，或用 `GH_REPO=owner/repo` 顶替探测。

⚠️ **加了 `-f`/`-F` 参数会自动把方法切成 POST**——只改 GET 查询串必须显式 `-X GET`：`gh api search/issues -X GET -f q='repo:cli/cli is:open'`（不写会 POST 到 `/search/issues` → 404 Not Found）。`--paginate` 翻 REST 全部页；GraphQL 翻页要 query 里带 `$endCursor: String` 与 `pageInfo{hasNextPage endCursor}`，再配 `--slurp` 包成外层数组。其它常用：`--cache 1h` `--silent` `-H 'Accept: ...'` `--input file.json` `--include` `--verbose`。

**写操作（issue/pr/release create、repo fork 等）会改远端状态，执行前必须得到用户明确确认。**

## 11. 回答格式

找库→项目名/★/主语言/最近推送/简介/适用场景/URL；排雷→方案摘要（注明 issue/PR 编号与 closed/merged 状态）/原文 URL；学源码→关键片段/文件路径/实现逻辑；追历史→commit 短哈希/作者/日期/消息首行。结论必标来源 URL，未跑命令得到的推断要明说。

## 12. 已知坑位（实测）

**语法 / 参数**

- `--` 之后的一切都当**查询文本**（其后的 flag 也会被吞掉），所以 `--` 必须是最后一个 flag、紧贴含连字符的 query：`gh search issues -- "my-query -label:bug"`；放错位置会让过滤全失效并退回默认表格输出（PowerShell 还要加 `--%`）。
- `gh search prs --state` 只接受 `open|closed`（合并用 `--merged`，草稿用 `--draft`），但 `gh pr list --state` 接受 `open|closed|merged|all`（`gh issue list --state` 接受 `open|closed|all`）——别混用。
- `--template` 必须配 `--json`，遍历数组写 `{{range .}}`（漏点报 `missing value for range`）。
- 否定词 `-term` 在 API 层有效（total_count 60945→1024），但首页结果可能仍含该词 —— 以 `total_count` 判断。
- `--search-type semantic|hybrid` 是相关性排序：不能配 `--sort`/`--order`，只返回单页；**仅 issues 支持**（prs 无此 flag），且 **GHES 上不可用**。
- `--jq` 引用未列入 `--json` 的字段只会拿到 null（`--json` 只取你列的字段；字段名拼错则报错）→ 遇 null 先把 `--json` 留空查合法字段名。

**字段名**

- `gh search repos` 用 `stargazersCount`/`language`；`gh repo view` 用 `stargazerCount`/`forkCount`/`primaryLanguage`（`search repos --json primaryLanguage` 无效，默认分支是 `defaultBranchRef`）。
- `gh search commits --json` 共 8 个字段（author commit committer id parents repository sha url），**顶层无 `message`**，消息在 `.commit.message` 里。
- `gh search code` 与写操作需要认证。
- CJK 复合关键词（如"OpenCodeV2 远程控制"）常返 0 结果；拆成英文词重搜即可命中中文 README 的项目。

**本地环境**

- `GH_TOKEN` 存在就必定带上，令牌无效时**全部**命令 401 且不回退匿名（匿名也跑不了 `gh search`）。官方明确环境变量令牌**优先于已存凭据**，所以失效的 `GH_TOKEN` 会盖掉 `hosts.yml` 里的好凭据 → 跑 `scripts/gh-setup-auth.sh` 恢复，或临时 `env -u GH_TOKEN gh ...`。
- `gh auth login --with-token` 在 `GH_TOKEN` 仍存在时拒绝存凭据，必须 `env -u GH_TOKEN -u GITHUB_TOKEN gh auth login --with-token`；失败时快速报错，不会卡在交互。
- `gh api rate_limit` 对 classic PAT 只返回 `core` 资源，`search` 字段为 null；认证后总配额 5000/小时。
- 本机若配了代理（如 `http://127.0.0.1:7890`），连接正常就别为"直连"去改代理变量。

---

上游：JayTing511/claude-github-kb-skill（MIT）。修正其 4 处失效命令，并按 gh 2.102.0 官方手册（213 个命令页）核对补全搜索限定符、PR/Release/CI 读取、`gh api` 分页与 GraphQL 变量、`gh skill`。本地适配：相对脚本路径、gh 2.102.0 基准、令牌认证链路（三个 scripts/）、本地知识库候选路径。
