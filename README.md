# llzz-skill

`llzz-skill` 是一个给 Codex 使用的本地技能项目，以 Obsidian vault 根目录的「笔记地图」为规则大脑，完成笔记的写入、读取问答、地图初始化与维护。

核心机制：**`笔记地图.md` 是单一事实来源**。AI 每次读写笔记前必读地图，严格按里面的分类规则和用户偏好执行。

## 触发条件

当用户说「林林总总」、`llzz`、「记到/整理到林林总总」，或要求从 Obsidian 笔记中查找内容时触发。

```text
林林总总：今天晚上去健身了，练了背，感觉状态还行。
```

```text
llzz 记一下：明天下午三点要和装修公司确认方案。
```

```text
查一下我笔记里关于 PawLingo 部署的记录
```

## 工作流

1. **定位 vault**：脚本自动搜寻本机 Obsidian vault，优先选择含 `笔记地图.md` 的。
2. **地图初始化**（无地图时）：扫描全部内容 → 提出分类方案 → 用户同意后创建。
3. **地图维护**：每次使用顺带检测漂移；小修正自动改，结构性变更需用户确认。
4. **写入**：按地图分类规则归档；目标文件夹不存在自动建；违反地图约束（如分类上限）时不擅自新增分类。
5. **读取/问答**：先看地图推断最可能的分类文件夹，优先搜索，未找到再全量搜索。

## vault 定位

不写死路径，按优先级自动搜寻：

1. 解析 `~/Library/Application Support/obsidian/obsidian.json` 注册的 vault（按最近使用排序）。
2. 扫描 iCloud Obsidian 容器 `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/*`。
3. 扫描 `~/Documents`、`~/Obsidian`、`~/Notes` 等常见目录。
4. 含 `.obsidian` 子目录的才算有效 vault；第一个含 `笔记地图.md` 的即为目标。

定位结果缓存到 `~/.config/llzz/vault-root`，可用环境变量 `LLZZ_VAULT` 显式覆盖。

手动执行定位：

```bash
zsh skills/llzz/scripts/find-vault.sh --rescan
```

## 目录结构

```text
llzz-skill/
├── README.md
├── docs/
│   └── 笔记地图工作流需求.md
├── scripts/
│   └── install.sh
└── skills/
    └── llzz/
        ├── SKILL.md
        ├── scripts/
        │   └── find-vault.sh
        ├── references/
        │   └── 笔记地图模板.md
        └── agents/
            └── openai.yaml
```

- `skills/llzz/SKILL.md`：技能主体，包含触发条件、五大工作流、文件选择规则和写入格式。
- `skills/llzz/scripts/find-vault.sh`：自动定位本机 Obsidian vault 根目录。
- `skills/llzz/references/笔记地图模板.md`：初始化笔记地图时使用的模板。
- `docs/笔记地图工作流需求.md`：工作流需求与已确认决策记录。

## 安装

```bash
cd /Users/ziheng/Projects/linlinzongzong-skills
zsh scripts/install.sh
```

脚本把 `skills/llzz` 同步到 `/Users/ziheng/.codex/skills/llzz`；目标已存在时先备份为带时间戳的目录。

## 验证

```bash
test -f /Users/ziheng/.codex/skills/llzz/SKILL.md
zsh /Users/ziheng/.codex/skills/llzz/scripts/find-vault.sh --rescan
```

第二条命令应输出含 `笔记地图.md` 的 vault 根目录路径。

## 维护规则

更新技能时优先修改 `skills/llzz/SKILL.md`；技能名称、简介、默认 prompt 变化时同步 `skills/llzz/agents/openai.yaml`；修改后运行 `zsh scripts/install.sh`。

## 当前边界

`llzz` 是笔记工作流助手，不是专业诊断、法律意见或财务建议工具。涉及身体不适、医疗判断、法律风险或资金决策时，它可以帮助保存和整理记录，但不能替代专业人士。
