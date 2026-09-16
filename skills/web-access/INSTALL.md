# 安装与上手（自动浏览器 skill）

> 本包是在 [web-access](https://github.com/eze-is/web-access) v2.5.4（作者「一泽Eze」，MIT 许可）基础上，**增补实战运维文档后**的完整可分发版本。
> 原版脚本与文档未作删改；新增内容见文末「包内文件说明」。
> 增补与整理：**白音**

---

## 一、这个 skill 能做什么

给 AI 接上**你自己日常使用的浏览器**，让它能真正地看网页、点按钮、填表单、抓取需要登录才能看的内容。

主要能力：

| 能力 | 说明 |
|---|---|
| 三层联网通道调度 | WebSearch / WebFetch / curl / Jina / CDP 按场景自主判断并组合 |
| 直连真实浏览器 | 通过 CDP 接管日常 Chrome / Edge，**天然带登录态，无需重新登录** |
| 完整交互 | 点击（JS 层 + CDP 真实鼠标事件）、滚动加载、填表提交、文件上传、截图 |
| 执行任意 JS | 读 DOM、提取数据、穿透 Shadow DOM 与 iframe |
| 本地书签/历史检索 | 搜「我之前看过的那个 X」这类公网搜不到的目标（需 `sqlite3`） |
| 视频截帧分析 | 操控 `<video>` 元素 seek 采样，让 AI 看懂视频内容 |
| 站点经验累积 | 按域名记录 URL 模式、平台特征、已知陷阱，跨会话复用 |
| 并行分治 | 多目标时派子 Agent 并行跑，共享一个浏览器、tab 级隔离 |

---

## 二、环境要求

| 项目 | 要求 | 检查命令 |
|---|---|---|
| **Node.js** | **22 或更高**（依赖原生 WebSocket） | `node --version` |
| 浏览器 | **仅支持 Chrome / Edge / Chromium / Chrome Canary** | 见下方说明 |
| 操作系统 | Windows / macOS / Linux 均可 | — |
| `sqlite3`（可选） | 仅「本地书签/历史检索」功能需要 | `sqlite3 -version` |

> **Node 版本低于 22 会在前置检查阶段直接失败**，不会静默出错。先确认这一条。
> 没装 Node 或需要升级：到 <https://nodejs.org> 下载 **LTS** 版安装即可，装完重开终端验证。

### ⚠️ 浏览器必须落在支持列表内

脚本的自动探测**只识别这四个**：

| ✅ 支持 | ❌ 不支持 |
|---|---|
| Chrome、Chrome Canary、Microsoft Edge、Chromium | Brave、Vivaldi、Opera、360 极速、QQ 浏览器等 |

右边这组虽然同样是 Chromium 内核，但脚本**不会去探测它们的调试端口**，会直接停在 `browser: 未连接`，无论你怎么开开关都无效。

如果你日常只用右边那类浏览器，最省事的做法是**额外装一个 Chrome 或 Edge 专门给 AI 用**。

`sqlite3` 不装不影响其它任何功能 —— 只有 `find-url.mjs`（检索本地书签/历史）会报错。

---

## 三、安装

### 步骤 1：解压并放置

把压缩包里的 **`web-access` 整个文件夹**放到 WorkBuddy 的 skills 目录下。

**用户级**（推荐，所有项目都能用）：

| 系统 | 目标路径 |
|---|---|
| Windows | `C:\Users\<你的用户名>\.workbuddy\skills\` |
| macOS / Linux | `~/.workbuddy/skills/` |

**项目级**（只在某个项目里生效）：放到 `<项目目录>/.workbuddy/skills/`

放置后的目录结构应为：

```
.workbuddy/skills/web-access/
├── SKILL.md
├── INSTALL.md
├── README.md
├── scripts/
├── templates/
└── references/
```

⚠️ **不要多套一层目录**。如果解压后得到的是 `web-access/web-access/SKILL.md`，把里层那个 `web-access` 移出来。

### 步骤 2：重启 WorkBuddy

skill 在会话启动时加载。放好后**新开一个会话**（或重启应用）才能被识别。

### 步骤 3：打开浏览器远程调试开关

**这一步必须由你手动完成，AI 代替不了** —— Chromium 的设计如此，就是为了防止程序静默接管浏览器。

1. 打开你日常使用的浏览器，**新开一个标签页**
2. 地址栏输入（注意**不能省略 `#remote-debugging` 这一段**）：

   | 浏览器 | 地址 |
   |---|---|
   | Edge | `edge://inspect/#remote-debugging` |
   | Chrome | `chrome://inspect/#remote-debugging` |

3. 找到复选框 **"Allow remote debugging for this browser instance"**，勾选
4. 若弹出权限确认，点 **Allow**
5. **确认成功标志**：勾选后页面下方会出现一行

   ```
   Server running at: 127.0.0.1:9222
   ```

   **看到这行才算成功。** 没看到就是没生效，重做一遍。

> ⚠️ 只输入 `edge://inspect`（不带 `#remote-debugging`）会进到设备列表页，**那里没有这个复选框**。这是最常见的失败原因。
>
> 另外：调试端口只在**当前浏览器实例**存活期间有效。浏览器关掉后需要重新勾选一次。

### 步骤 4：验证

在 WorkBuddy 里说一句：

> 用 web-access 做一次前置检查

或者手动跑：

```bash
node "<你的 skills 目录>/web-access/scripts/check-deps.mjs"
```

**全部通过时的输出**应类似：

```
node:    ok (v22.x.x)
config:  ...
browser: ok — Microsoft Edge (端口 9222)
proxy:   ready
```

---

## 四、首次使用

### 让 AI 自己加载

正常描述你的需求即可，例如：

- 「读一下这篇文章 https://...」
- 「去 XX 网站帮我查一下 YY」
- 「把这篇公众号文章正文原样保存下来」

skill 会按描述自动触发。

### 需要手动指定的场景

如果没自动触发，可以明确说：

> 必须加载 web-access skill 并遵循指引

---

## 五、常见问题

### 执行脚本报「系统找不到指定的路径」/ 路径里带着 `${CLAUDE_SKILL_DIR}` 字样

包内 `SKILL.md` 用 `${CLAUDE_SKILL_DIR}` 来引用 skill 自己的目录，这个变量**由 Agent 平台在加载 skill 时自动替换**，不是 shell 环境变量。

| 平台 | 行为 |
|---|---|
| Claude Code | 支持（原版即为此设计） |
| WorkBuddy | **实测支持**，会替换为绝对路径 |
| 其它平台 | **不保证** |

**怎么判断是不是这个问题**：报错信息里出现字面量 `${CLAUDE_SKILL_DIR}`，或提示路径不存在，而文件其实就在那儿。

**怎么修**：把 `SKILL.md` 里所有 `${CLAUDE_SKILL_DIR}` 换成实际绝对路径。

```bash
# 替换前
node "${CLAUDE_SKILL_DIR}/scripts/check-deps.mjs"

# Windows 替换后
node "C:/Users/<用户名>/.workbuddy/skills/web-access/scripts/check-deps.mjs"

# macOS / Linux 替换后
node "$HOME/.workbuddy/skills/web-access/scripts/check-deps.mjs"
```

最省事的方式是直接让 AI 做：

> 这个 skill 里的 `${CLAUDE_SKILL_DIR}` 好像没被替换，请把它全部改成当前 skill 目录的绝对路径

### 前置检查报 `browser: 未连接`

调试开关没生效。按「步骤 3」重做，并**确认看到 `Server running at: 127.0.0.1:9222` 那一行**。

### 每次操作都要我在浏览器里点授权

这是**使用方式**问题，不是配置问题。

`check-deps.mjs` 会把 proxy 拉起，但如果执行环境在**每条命令结束时回收子进程**，proxy 就会随之被杀；下一轮重新拉起时，浏览器会要求重新授权。

**解法**：不要让 AI 每步都跑 `check-deps`，而是**以后台常驻方式启动一次 proxy**，之后所有请求直接打 `http://localhost:3456`。

详细说明见 `SKILL.md` 的「⚡ 关键：Proxy 必须常驻」一节，以及 `references/ops-pitfalls.md` 的 P-X1。

### 点击返回成功，但页面没有任何变化

按顺序查三件事：

1. **选择器是否唯一** —— `document.querySelectorAll(选择器).length`，大于 1 就必须加作用域前缀（`/click` 与 `/clickAt` 只作用于第一个匹配元素）
2. **是否有遮挡层** —— `document.elementFromPoint(x, y)`，返回 `IFRAME` 或弹窗容器说明点击没落到目标上
3. **是否用错了 API** —— JS 合成的 `/click` 会被部分站点忽略（`isTrusted=false`），改用 `/clickAt` 的真实鼠标事件

完整案例见 `references/ops-pitfalls.md` 的 P-O1 ~ P-O5。

### 取不到折叠区块里的文字

带 `display:none` 的元素上 `innerText` 返回空，**改用 `textContent`**。而且这类内容通常**不用点开「展开」就能直接取到**。

### 需要「原样搬运」网页文字（不得改写）

不要让 AI 把正文读进上下文再打出来 —— 长文本上会有漏段、合段、同义替换的风险。

改用「页面 → 临时文件 → 脚本落盘」三段式，详见 `references/ops-capture-fidelity.md`（含可直接复用的脚本模板）。

### 想让 AI 操作但不想每次都授权（进阶）

Chromium 136 之后，命令行直开调试端口必须配一个**全新的 `--user-data-dir`**，即一个独立的浏览器实例。好处是完全不需要授权，代价是**所有站点都要重新登录一次**。

一次性任务不值得，长期无人值守的自动化才值得考虑。

---

## 六、安全说明与注意事项

**本 skill 会做什么**

- 在你本机启动一个 HTTP 服务（`127.0.0.1:3456`），**仅监听回环地址**，不对外暴露
- 通过 CDP 连接你的浏览器，**在你已登录的账号上下文中**操作页面
- `find-url.mjs` 会读取本机 Chrome / Edge 的书签与历史库（拷到临时文件后查询，用完删除）
- `/screenshot?file=` 与 `/setFiles` 接受任意本地路径，可用于读写文件

**你需要知道的**

1. **3456 端口无鉴权** —— 同机任意进程都能调用，等价于拿到你浏览器的控制权。这是设计取舍，但应当知晓。
2. **自动化操作可能触发站点风控** —— 部分站点对浏览器自动化检测严格，存在**账号被限流或封禁**的风险。作者已在 skill 内要求 AI 在操作前展示风险提示。
3. **社交类写操作不可逆** —— 点赞、关注、收藏绑定真实账号；**关注会通知对方**，并永久留在你的公开关注列表里。
4. **不要在不信任的机器上长期开启调试端口** —— 用完可在同一页面取消勾选。

**建议**：涉及真实账号的写操作（点赞/关注/评论/发布），先让 AI 说明它打算做什么，确认范围后再放行。

---

## 七、包内文件说明

```
web-access/
├── SKILL.md                  主入口。原版正文 + 三处运维补充
├── INSTALL.md                本文件
├── README.md                 上游原版 README（含 GitHub 来源信息）
├── scripts/
│   ├── cdp-proxy.mjs         核心：常驻 HTTP 服务，把 CDP 包成 REST API
│   ├── check-deps.mjs        前置检查：Node / 浏览器端口 / proxy 状态
│   ├── browser-discovery.mjs 浏览器探测（找可用的调试端口）
│   ├── find-url.mjs          本地书签/历史检索（依赖 sqlite3）
│   └── match-site.mjs        站点经验匹配
├── templates/
│   └── config.env.template   配置模板
└── references/
    ├── cdp-api.md            CDP API 详细参考
    ├── migration-2.5.3.md    上游迁移说明
    ├── ops-pitfalls.md       ★ 新增：27 条实测坑与对策
    ├── ops-env-adaptation.md ★ 新增：执行环境适配与替代写法
    ├── ops-capture-fidelity.md ★ 新增：保真采集链路
    └── site-patterns/        站点经验库（按域名，可持续累积）
        ├── miyoushe.com.md
        └── baike.mihoyo.com.md
```

★ 标记的三份为本包新增，来自实际部署验证，非推测。原版内容未作删改。

---

## 八、卸载

1. 删除 skills 目录下的 `web-access` 文件夹
2. 在浏览器里取消勾选远程调试（`edge://inspect/#remote-debugging` 或 `chrome://inspect/#remote-debugging`）
3. 若 proxy 仍在运行，结束对应的 node 进程即可

---

## 授权

原版 web-access 采用 **MIT 许可**，允许自由使用、修改与再分发，请保留原作者信息（见 `README.md` 与 `SKILL.md` 的 frontmatter）。

本包新增的三份 `ops-*` 文档与 `INSTALL.md` 为实战补充，以 MIT 许可发布，作者：**白音**，随本包一并分发。
