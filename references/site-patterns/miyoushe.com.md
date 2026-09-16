---
domain: miyoushe.com
aliases: [米游社, 原神社区, miHoYo bbs, 米哈游社区]
updated: 2026-09-16
---

## 平台特征

- 主体为 Vue 2 + 服务端渲染（SSR）的社区站；CSS 类名前缀 `mhy-`。PC 端与移动端 (`bbs.miyoushe.com`) 是两套模板，选择器不通用。
- **公开页面可静态抓取**（实测 2026-09-16）：`https://www.miyoushe.com/ys/` 与文章页 `curl` 均返回 200，正文在 HTML 里；Jina Reader（`r.jina.ai/`）也能提取到结构化内容。适合只读任务，节省 token。
- **静态层无登录态**：SSR 出来的账号链接是 `/ys/accountCenter/postList?id=undefined`（游客视角）。任何写操作（点赞/收藏/关注/评论/投稿）必须走浏览器 CDP，走真实用户的登录态。
- 登录态判断不能只看 `document.cookie`：`account_id`、`ltuid`、`account_id_v2`、`ltmid_v2`、`ltuid_v2` 这些**未登录也会存在**（设备/访客标识）。真正的鉴权 cookie 是 `ltoken_v2` / `stoken_v2` / `cookie_token_v2`，均为 httpOnly，读不到。
  - 更可靠的登录判据：页头 `a.header__avatar img` 的 src。已登录是真实上传头像（`bbs-static.miyoushe.com/communityweb/upload/...`），未登录是 `avatar/avatarDefaultPc.png`。
- 板块路径前缀即游戏代号：`/ys/`（原神）、`/bh3/`、`/sr/` 等。文章 ID 为纯数字，跨板块唯一。

## 有效模式

### 文章列表与正文（只读，优先静态）

- 板块首页 `https://www.miyoushe.com/ys/`：SSR 直出文章卡片。提取列表用 `a[href*="/ys/article/"]`。
- 文章页 `https://www.miyoushe.com/ys/article/<数字ID>`，可直接 navigate，无需携带会话参数。
- 正文文本：`document.body.innerText` 即可拿到（实测 textLen 约 2700–4000）。

### 点赞（已验证 2026-09-16）

**真正的点赞按钮在左侧竖排浮动操作栏，不在顶部信息栏。**

```
.mhy-article-actions              ← 固定定位的竖排栏（position: fixed）
├── .mhy-article-actions__item  #1  留言数（图标 icon-liuyanshu）
├── .mhy-article-actions__item  #2  收藏数（svg #icon-shoucang）
├── .mhy-article-actions__item  #3  点赞数  ← 内含 .mhy-heart-click
│   └── .mhy-heart-click  >  svg.mhy-heart-click__icon > use[href="#icon-dianzanpc"]
└── .mhy-article-actions__item  #4  管理/更多（.manage-icon）
```

- 点击目标：**`.mhy-article-actions .mhy-heart-click`**（约 30×30 CSS px，视口坐标不随滚动变化，因为整栏 fixed）。
- **必须带 `.mhy-article-actions` 前缀**。全页有 27 个 `.mhy-heart-click`（右侧评论区每个留言卡片各一个），`clickAt` 只作用于第一个匹配元素，不加前缀会点到评论区的点赞上，表现为「点击成功但文章计数不变」。
- 需要**真实鼠标事件**（`/clickAt`，走 CDP `Input.dispatchMouseEvent`）。`/click`（JS `el.click()`）在 2026-09-16 的实测中对本按钮**无效果**（合成事件 isTrusted=false）。
- 顶部 `.mhy-article-page-info__count`（留言/点赞/收藏那排数字）是**只读展示**，点击无任何反应——不要把它当点赞入口。

### 验证点赞是否成功

- **这个布局没有「已赞」视觉状态**。扫描 187 个 stylesheet，含 `heart-click` 的规则只有三条（cursor、display、评论区的 font-size / span color），**没有任何 active / liked / selected 样式**；图标 `<use>` 的 computed fill 恒为 `rgb(51,51,51)`。
- 所以判断只能靠**计数**：读 `.mhy-article-actions` 的 innerText（形如 `45 41 1160` = 留言数 收藏数 点赞数），然后**重新 navigate 同一 URL 重载**，确认服务端也返回新计数。
- 计数变化是异步的，点击后要等 3–5 秒再读。

### 页面内导航

- 文章链接可直接构造导航；站内搜索、板块切换等建议用 `/click` 走可交互单元，URL 天然带全上下文。

## 已知陷阱

- **登录平台 iframe 全屏遮挡**（实测 2026-09-16）：需要登录的交互会拉起 `https://user.miyoushe.com/login-platform/index.html?app_id=bll8iq97cem8&...`，以**两个全视口 iframe（1528×732）**覆盖页面，同时 `<body>` 加上 `mhy-login-platform__overflow-hidden`。此后 `document.elementFromPoint(x,y)` 返回 `IFRAME`，**任何鼠标点击都打不到页面元素**，表现为「clicked:true 但毫无反应」。
  - 排查手法：点击前先 `document.elementFromPoint(x, y).tagName`（或看 `document.body.className` 是否含 `mhy-login-platform`）。命中 iframe 就先处理遮挡。
  - 关闭：派发 Escape（`document.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape",keyCode:27,bubbles:true}))`）可移除 body 上的遮挡类并恢复命中；实测有效。
- **不要用 `/json/version` 判断调试端口是否可用**：新版 Chromium 对 `127.0.0.1:9222/json/version` 返回 **404**（发现接口被收紧），但端口是正常工作的，proxy 会改走 `ws://127.0.0.1:9222/devtools/browser`。看到 404 不等于没开。
- **点赞等计数型指标存在并发干扰**：官方活动帖点赞基数随时在涨，仅凭「计数 +1」不能 100% 断定是自己的操作生效，务必配合重载后服务端计数一起判断。
- 自动化点赞/关注属于米游社风控关注的行为，官方帖（`来自版块：官方`）风险最低；对普通用户帖点赞/关注会产生对方可见的互动记录。
