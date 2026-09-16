# AI 技能库

> 给 WorkBuddy / Claude Code 等 AI Agent 使用的实用技能（Skill）集合。
> 每个技能都是经过实际部署验证的完整能力包，下载即可用。

---

## 这是什么

Skill 是给 AI Agent 扩展能力的「能力包」——一个文件夹，里面放一份 `SKILL.md` 和配套的脚本、文档，AI 就能学会一项新本事。

本仓库收录的是**实际用起来、踩过坑、验证过**的技能，不是从别处抄来的清单。

**为什么值得用**：每个技能里都附了实测遇到的坑与对策。这些内容在官方文档里找不到——它们是真正跑起来才会撞上的问题。

---

## 快速开始

### 方式一：下载即用（推荐，无需任何命令行）

1. 到本仓库的 [**Releases**](../../releases) 页面，下载最新版压缩包
2. 解压，得到技能文件夹
3. 把技能文件夹**整个**放进下面这个目录：

   | 系统 | 目录 |
   |---|---|
   | Windows | `C:\Users\<你的用户名>\.workbuddy\skills\` |
   | macOS / Linux | `~/.workbuddy/skills/` |

4. **重启 WorkBuddy**（技能在会话启动时加载，新开一个会话即可）

最终结构应该是这样，**不要多套一层目录**：

```
.workbuddy/skills/
└── web-access/
    ├── SKILL.md
    ├── INSTALL.md
    ├── scripts/
    └── references/
```

### 方式二：命令行安装（适合开发者）

```bash
git clone https://github.com/Honey-YY/baiyinGH.git
cd baiyinGH

# macOS / Linux / Git Bash
bash install.sh

# Windows PowerShell
powershell -ExecutionPolicy Bypass -File install.ps1
```

脚本会列出可安装的技能，选好后自动复制到 skills 目录。

---

## 技能清单

| 技能 | 用途 | 依赖 | 文档 |
|---|---|---|---|
| **web-access** | 让 AI 真正地看网页、点按钮、填表单、抓取需登录才能看的内容 | Node.js 22+、浏览器 | [查看](skills/web-access/INSTALL.md) |

> 本库持续更新中，新技能会陆续加入。**Star 或 Watch 本仓库**可收到更新通知。

---

## 技能详情：web-access

### 它解决什么问题

网页抓取工具最大的限制是**没有登录态**——需要登录才能看的内容一律拿不到，反爬严格的站点（公众号、小红书等）也基本抓不到正文。

这个技能通过 CDP 协议**接管你日常使用的浏览器**，天然带着你的登录状态，因此能做静态抓取做不到的事。

### 主要能力

| 能力 | 说明 |
|---|---|
| 三层联网通道调度 | WebSearch / WebFetch / curl / Jina / CDP 按场景自主判断并组合 |
| 直连真实浏览器 | 接管日常 Chrome / Edge，**带你的登录态，无需重新登录** |
| 完整交互 | 点击（JS 层 + 真实鼠标事件）、滚动加载、填表提交、文件上传、截图 |
| 执行任意 JS | 读 DOM、提取数据、穿透 Shadow DOM 与 iframe |
| 本地书签/历史检索 | 搜「我之前看过的那个 X」这类公网搜不到的目标（需 `sqlite3`） |
| 视频截帧分析 | 操控 `<video>` 元素 seek 采样，让 AI 看懂视频内容 |
| 站点经验累积 | 按域名记录 URL 模式与已知陷阱，跨会话复用 |

### 安装配置的完整说明

见 [skills/web-access/INSTALL.md](skills/web-access/INSTALL.md)。**首次使用必读**——有三个必须手动完成的准备步骤。

### 特色：内置实战避坑文档

这是本库与别处不同的地方。技能内附了三份实测文档：

| 文档 | 内容 |
|---|---|
| [ops-pitfalls.md](skills/web-access/references/ops-pitfalls.md) | 27 条实测坑与对策，分 6 类 |
| [ops-env-adaptation.md](skills/web-access/references/ops-env-adaptation.md) | 执行环境适配与替代写法 |
| [ops-capture-fidelity.md](skills/web-access/references/ops-capture-fidelity.md) | 保真采集链路（原文逐字搬运，不改写） |

外加按域名积累的站点经验库 `references/site-patterns/`。

---

## 常见问题

### 技能没被识别 / 用了没反应

1. 检查目录结构——`SKILL.md` 必须在技能文件夹的**第一层**，不能多套一层
2. 检查是否**重启了 WorkBuddy**（技能在会话启动时加载）
3. 在对话里明确指定：`必须加载 web-access skill 并遵循指引`

### 前置检查报错怎么办

见 [skills/web-access/INSTALL.md](skills/web-access/INSTALL.md) 的「常见问题」章节，覆盖了最常见的几类：

- `browser: 未连接` —— 调试开关没生效
- 路径里出现 `${CLAUDE_SKILL_DIR}` 字样 —— 平台未替换变量
- 每次都要求浏览器授权 —— proxy 未常驻

### 支持哪些浏览器

**仅支持 Chrome / Edge / Chromium / Chrome Canary。**

Brave、Vivaldi、Opera、360 极速、QQ 浏览器等虽然同为 Chromium 内核，但**不被识别**。如果你日常只用这类浏览器，建议另装一个 Chrome 或 Edge。

### 有风险吗

**有，必须知道：**

1. **3456 端口无鉴权** —— 同机任意进程都能调用，等价于拿到你浏览器的控制权
2. **自动化操作可能触发站点风控** —— 部分平台对自动化检测严格，存在账号被限流的风险
3. **社交类写操作不可逆** —— 点赞、关注、收藏绑定真实账号，**关注会通知对方**

技能会在操作前提示风险。涉及真实账号的写操作，建议先让 AI 说明打算做什么再放行。

---

## 许可与致谢

本仓库以 **MIT 许可**发布，可自由使用、修改、分发。

- **维护者**：白音
- **许可**：[MIT](LICENSE)

**本项目基于开源项目 [web-access](https://github.com/eze-is/web-access)（作者：[一泽 Eze](https://github.com/eze-is)，MIT 许可）整理与增补。**

`skills/web-access/` 下的核心脚本与文档来自该项目，版权归原作者所有；新增的实战避坑文档与仓库组织文件由 **白音** 撰写。详见 [LICENSE](LICENSE)。

如果这个项目对你有帮助，建议也给原作者点个 Star。

---

## 反馈与贡献

- 遇到问题 → 提 [Issue](../../issues)
- 发现更好的方法 → 欢迎 PR
- 想要某个新技能 → 在 Issue 里描述你的场景

---

## 更新日志

| 版本 | 日期 | 内容 |
|---|---|---|
| v1.0.0 | 2026-09-16 | 首次发布，收录 web-access 及配套实战文档 |
