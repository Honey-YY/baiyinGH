# web-access skill

> **一个 skill，让 AI 真正地操作你的浏览器。**
> 下载即用，附带实测踩过的坑与对策。

本仓库就是这一个技能本身——仓库根目录的 `SKILL.md` 即技能定义，克隆/解压后直接放进 AI 的 skills 目录就能用。

---

## 这是什么

Skill 是给 AI Agent 扩展能力的「能力包」——一个文件夹，里面放一份 `SKILL.md` 和配套的脚本、文档，AI 就能学会一项新本事。

本仓库收录的是**实际用起来、踩过坑、验证过**的 `web-access`：在上游开源项目基础上，增补了一份实战运维文档。这些内容在官方文档里找不到——它们是真正跑起来才会撞上的问题。

---

## 快速开始

### 方式一：下载即用（推荐，无需任何命令行）

1. 到本仓库的 [**Releases**](../../releases) 页面，下载最新版压缩包
2. 解压，得到 `web-access` 文件夹
3. 把这个文件夹**整个**放进下面这个目录：

   | 系统 | 目录 |
   |---|---|
   | Windows | `C:\Users\<你的用户名>\.workbuddy\skills\` |
   | macOS / Linux | `~/.workbuddy/skills/` |

4. **重启 AI 客户端**（技能在会话启动时加载，新开一个会话即可）

最终结构应该是这样，**不要多套一层目录**：

```
.workbuddy/skills/
└── web-access/
    ├── SKILL.md
    ├── INSTALL.md
    ├── scripts/
    ├── references/
    └── templates/
```

### 方式二：命令行安装（适合开发者）

```bash
git clone https://github.com/Honey-YY/web-access-skill.git
cd web-access-skill

# macOS / Linux / Git Bash
bash install.sh

# Windows
powershell -ExecutionPolicy Bypass -File install.ps1
```

也可以**直接把仓库克隆成技能目录**，跳过安装脚本：

```bash
git clone https://github.com/Honey-YY/web-access-skill.git ~/.workbuddy/skills/web-access
```

---

## 能力

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

见 [INSTALL.md](INSTALL.md)。**首次使用必读**——有三个必须手动完成的准备步骤。

---

## 特色：内置实战避坑文档

这是本版本与别处不同的地方。技能内附了三份实测文档：

| 文档 | 内容 |
|---|---|
| [ops-pitfalls.md](references/ops-pitfalls.md) | 27 条实测坑与对策，分 6 类 |
| [ops-env-adaptation.md](references/ops-env-adaptation.md) | 执行环境适配与替代写法 |
| [ops-capture-fidelity.md](references/ops-capture-fidelity.md) | 保真采集链路（原文逐字搬运，不改写） |

外加按域名积累的站点经验库 `references/site-patterns/`。

> 上游原版项目的 README（安装方式、版本更新记录、设计哲学）完整保留在
> [references/upstream-readme.md](references/upstream-readme.md)。

---

## 常见问题

### 技能没被识别 / 用了没反应

1. 检查目录结构——`SKILL.md` 必须在技能文件夹的**第一层**，不能多套一层
2. 检查是否**重启了客户端**（技能在会话启动时加载）
3. 在对话里明确指定：`必须加载 web-access skill 并遵循指引`

### 前置检查报错怎么办

见 [INSTALL.md](INSTALL.md) 的「常见问题」章节，覆盖了最常见的几类：

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

- **维护者**：白音
- **许可**：[MIT](LICENSE)

**本项目基于开源项目 [web-access](https://github.com/eze-is/web-access)（作者：[一泽 Eze](https://github.com/eze-is)，MIT 许可）整理与增补。**

原版的技能定义、脚本与文档来自该项目，版权归原作者所有；新增的实战避坑文档与仓库组织文件由 **白音** 撰写。详见 [LICENSE](LICENSE)。

如果这个项目对你有帮助，建议也给原作者点个 Star。

---

## 反馈与贡献

- 遇到问题 → 提 [Issue](../../issues)
- 发现更好的方法 → 欢迎 PR

---

## 更新日志

| 版本 | 日期 | 内容 |
|---|---|---|
| v1.0.1 | 2026-09-16 | 仓库改为「一个 skill 一个仓库」结构（根目录即技能）；分发包内补入 LICENSE；署名统一 |
| v1.0.0 | 2026-09-16 | 首次发布，收录 web-access 及配套实战文档 |
