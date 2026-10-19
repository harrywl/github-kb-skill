# github-kb

用 `gh` CLI 实时检索 GitHub 的**仓库 / Issue / PR / 代码 / 提交**，并可查询本地克隆的仓库知识库。

面向 AI Agent 与人 alike：本技能把 gh CLI 最容易踩的坑、字段名差异、认证链路整理成一份可直接执行的速查文档，避免一次次的试错。

---

## 这个技能解决什么

- **不要凭记忆回答 GitHub 问题** —— 涉及代码库、报错、项目对比时，先跑命令拿到真实数据，再给结论并附来源 URL。
- **gh 的 flag/字段名极易记错** —— `gh search repos` 用 `stargazersCount`（复数），`gh repo view` 用 `stargazerCount`（单数）；`gh repo view` 的默认分支字段是 `defaultBranchRef` 不是 `defaultBranch`；`gh search commits --json` 顶层没有 `message`。这些都写进文档了。
- **认证链路** —— 环境变量 `GH_TOKEN` 优先于已存凭据，令牌失效时 gh 全部命令 401 且**不退回匿名**。附一键恢复脚本。
- **两个真会踩的雷** —— `gh api` 加了 `-f/-F` 会**自动把方法切成 POST**；`--` 之后的一切都被当查询文本。

## 安装

把仓库里的 `SKILL.md` 和 `scripts/` 放进你的 agent 技能目录：

```bash
git clone <this-repo> github-kb
cp -r github-kb/SKILL.md github-kb/scripts/ <your-skills-dir>/github-kb/
```

或用 gh 直接装（gh 2.102.0+）：

```bash
gh skill install <owner>/<this-repo> --dir <your-skills-dir>
```

## 用法

1. 每个会话首次使用时自检一次：

   ```bash
   sh scripts/gh-env-check.sh     # KEY=VALUE 输出，exit 0 可用 / 1 有阻断
   ```

2. 按意图选命令（详见 `SKILL.md` §2 的映射表）：

   | 意图 | 命令 |
   |---|---|
   | 找库/找工具 | `gh search repos` |
   | 报错排查 | `gh search issues`（优先 `--state closed`） |
   | 看实现 | `gh search prs` + `gh search code` |
   | 改动何时引入 | `gh search commits` |
   | 仓库健康度 | `gh repo view --json` |
   | 复杂聚合查询 | `gh api`（REST/GraphQL） |

3. 令牌失效时的恢复流程见 `SKILL.md` §0。

## 脚本

| 脚本 | 作用 |
|---|---|
| `scripts/gh-env-check.sh` | 环境自检，输出 KEY=VALUE；有令牌且 gh 未登录时会自动注册凭据 |
| `scripts/gh-setup-auth.sh` | 用 `GH_TOKEN` 重新登录 gh（令牌换新后跑这一条即可） |
| `scripts/gh-api.sh` | REST 回退：curl 直连 api.github.com，令牌有效则用、否则匿名 |
| `scripts/fetch-official-docs.sh` | 抓取官方手册全部命令页并转纯文本，**用来核对本技能里的每一条断言** |

## 文档是怎么保证准确的

`SKILL.md` 里的每条 flag、字段名、行为约束都对照 **gh 官方手册全部 213 个命令页**核验过
（`https://cli.github.com/manual/`）。重新核对：

```bash
sh scripts/fetch-official-docs.sh ./gh-docs
grep -A2 '^--search-type' gh-docs/text/gh_search_issues.txt
```

文档里还标注了哪些是**手册可证**、哪些是**本机实测**。

## 前置条件

- `gh` ≥ 2.102（本文档的 `--search-type`、字段清单以此为准；低版本请以 `gh <cmd> --help` 为准）
- `jq`、`python3`、`curl`、`git`
- 一个 GitHub token（classic PAT 最小 scope：`repo,read:org,gist`；fine-grained 直接用环境变量 `GH_TOKEN`）

## 许可与致谢

本技能基于 [JayTing511/claude-github-kb-skill](https://github.com/JayTing511/claude-github-kb-skill)（MIT）改编，
修正了其中 4 处失效命令，并按 gh 官方手册扩充核验。详见 [LICENSE](LICENSE)。
