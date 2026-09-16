---
domain: baike.mihoyo.com
aliases: [观测枢, 原神观测枢, 米游社百科, 原神wiki, mihoyo baike, obc]
updated: 2026-09-16
---

## 平台特征

- 米哈游官方百科站（「观测枢」），从米游社页头导航进入。Vue 2 系 SPA，类名前缀 `obc-tmpl-`，组件库为 Element UI（存在 `el-tooltip`）。
- **无需登录即可读全部词条**（实测 2026-09-16）。词条正文在 DOM 中直接可取，**静/动态都可拿**，但页面体量很大（单个角色页 `body.innerText` 约 28,000 字符），走 CDP 读取要注意只取目标区块。
- 带 `?bbs_presentation_style=no_header` 参数时是嵌入米游社的样式；不带也能正常访问。URL 会被自动追加 `&visit_device=pc`。

### 入口

| 用途 | URL |
|---|---|
| 观测·攻略（首页） | `https://baike.mihoyo.com/ys/strategy/` |
| **观测·Wiki（词条库）** | `https://baike.mihoyo.com/ys/obc/` |
| 词条详情 | `https://baike.mihoyo.com/ys/obc/content/<数字ID>/detail` |

从米游社页头拿「观测枢」链接的方式：`a` 的 innerText 匹配 `/观测枢/`，href 指向 `baike.mihoyo.com/ys/strategy/`。

## 有效模式

### 站内搜索（受控输入框）

页头搜索框：`input[placeholder="搜索"]`（实测约 x=1168, y=18）。

**直接赋值 `input.value = "x"` 无效**（Vue 受控组件不感知）。必须走原生 setter + 派发事件：

```js
var inp = null;
document.querySelectorAll("input").forEach(function (i) {
  if (!inp && (i.getAttribute("placeholder") || "").indexOf("搜索") >= 0) inp = i;
});
var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
setter.call(inp, "伊涅芙");
inp.dispatchEvent(new Event("input", { bubbles: true }));
inp.dispatchEvent(new Event("change", { bubbles: true }));
inp.focus();
```

输入后约 2.5 秒出现候选下拉，取 `a[href*="/obc/content/"]` 即得词条直链。
**拿到直链后建议直接用 href 导航**，比点候选更稳。

### 词条正文的结构（核心）

词条页正文由若干 `.obc-tmpl-fold` 折叠面板组成，每个面板三段式：

```
.obc-tmpl-fold
├── .obc-tmpl-fold__title              标题（内含 span）
├── .obc-tmpl__paragraph-box display-none   ← 正文
└── .obc-tmpl__fold-tag show-expand     [ 展开 ] 按钮
```

- **正文容器带 `display-none`，但内容已在 DOM 中 —— 完全不用点开「展开」就能取到全文。**
- ⚠️ 因为元素不可见，**`innerText` 会返回空或不可靠，必须用 `textContent`**。
- 段落边界用容器内的 `<p>` 标签切分；取 `p.textContent` 再归一化空白即可保持原文段落划分。

提取模板：

```js
document.querySelectorAll(".obc-tmpl-fold").forEach(function (el) {
  var name = (el.querySelector(".obc-tmpl-fold__title") || {}).innerText;
  var box = el.querySelector(".obc-tmpl__paragraph-box");
  if (!box) return;
  var parts = [];
  box.querySelectorAll("p").forEach(function (p) {
    var s = (p.textContent || "").replace(/\s+/g, " ").trim();
    if (s) parts.push(s);
  });
  // name -> parts
});
```

### 角色词条的折叠面板清单（2026-09-16 实测，伊涅芙）

角色CV / 特殊料理 / 更多描述 / **角色详细** / **角色故事1** / **角色故事2** / **角色故事3** / **角色故事4** / **角色故事5** / 「薇尔琪塔」 / **月之轮** / 生日邮件 / 角色关联语音 / 角色关系网 / 关联词条

**取「角色故事文案」时应取：角色详细 + 角色故事1~5 + 月之轮（旧地区角色此处为「神之眼」）。**

## 已知陷阱

- **「神之眼」在诺德克拉（挪德卡莱）角色上叫「月之轮」**。2026-09-16 查伊涅芙时按「神之眼」匹配一无所获，按「月之轮」才命中。写抓取脚本时两个名字都要覆盖，别只匹配「神之眼」。
- 面板列表里存在**看似相关但不是角色故事**的条目（如伊涅芙的「薇尔琪塔」是随从机器人词条、另有「特殊料理」「生日邮件」「角色CV」）。**按标题白名单精确取，不要按「包含故事二字」模糊匹配**，否则会把非故事内容混进正文。
- 页面很长（实测约 8,900 px 高、28,000 字符文本），`/eval` 只取 `.obc-tmpl-fold` 内文本可避免把等级突破表、属性表一起捞进来。
- 有个 `?bbs_presentation_style=no_header` 参数在导航后会被站方改写（追加 `visit_device=pc`），属正常，不影响取内容。

## 采集正确性建议

需要「原文不得改写」的场景（文案搬运、二创素材），**不要让模型把正文转写到文件**（有转写/漏段风险）。改用「页面 → 临时文件 → 脚本落盘」三段式：

1. `/eval` 返回 `JSON.stringify(结果)`；
2. `curl ... -o tmp.json` 直接落盘；
3. 写一个 `.mjs` 读 tmp.json、拼装 Markdown、`fs.writeFileSync` 输出。

文字全程逐字传递，零模型转述。伊涅芙词条即用此法产出（7 节 + 1 附录，19,061 字节）。
