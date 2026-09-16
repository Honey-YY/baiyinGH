# 保真采集规范

> 适用场景：任务要求**原文不得改写**的文本采集 —— 文案搬运、二创素材、史料摘录、角色故事/台词整理、政策原文抄录等。
> 目标：让文字从页面到文件**全程逐字传递**，杜绝模型转述造成的改写与漏段。

---

## 一、核心原则：不要让模型经手正文

**错误链路**（有改写风险）：

```
页面 → /eval 取文本 → 模型读进上下文 → 模型把文字打进写文件工具 → 文件
                      ↑↑↑ 概率采样发生在这里 ↑↑↑
```

模型生成是概率采样。在长文本上会发生：

- **漏段**（尤其段落数 > 20 时）
- **段落合并**（把相邻短段落并成一段）
- **同义替换**（意思对但字不对）
- **标点规范化**（中文引号变英文、破折号变短横）

任务要求「不改写原文」时，这是**根本性冲突**，不是「小心一点」能解决的。

**正确链路（三段式）**：

```
① /eval      → 页面返回 JSON 字符串
② curl -o    → 直接落盘成临时文件（模型不读内容）
③ 脚本       → 读临时文件 → 拼 Markdown → 写出
```

文字从页面到文件**全程逐字传递**，模型只在第 ③ 步知道「有哪些键」，不接触正文内容。

---

## 二、三步操作详解

### 第 ① 步：在页面内提取，返回 JSON 字符串

用 `/eval` 执行一个立即执行函数，**内部 `JSON.stringify`**，返回值即为可落盘的 JSON。

关键点：

- 用 **`textContent`** 而非 `innerText`（目标容器常带 `display:none`，见 `ops-pitfalls.md` P-O6）
- **按容器内的段落标签切分**，而不是把整块文本当一个字符串 —— 这样能保留原文段落划分
- 归一化空白：`replace(/\s+/g, " ").trim()`，仅处理空格/换行，**不碰任何标点**
- **按标题白名单精确匹配**，不用模糊正则（见 P-D2）

```bash
curl -s -m 20 -X POST "http://localhost:3456/eval?target=$T" -d '
(function () {
  // ①-1 白名单：精确列名，不要模糊匹配
  //      实际使用前，先用另一段脚本打印出全部候选标题再决定（见「五、领域术语变体」）
  var want = ["章节名A", "章节名B", "章节名C"];

  var res = {};
  document.querySelectorAll(".面板选择器").forEach(function (el) {
    var t = el.querySelector(".标题选择器");
    var name = t ? (t.textContent || "").trim() : "";
    if (want.indexOf(name) < 0) return;              // 精确命中才取

    var box = el.querySelector(".正文选择器");
    var parts = [];
    if (box) {
      // 用 textContent；按段落标签切分
      box.querySelectorAll("p").forEach(function (p) {
        var s = (p.textContent || "").replace(/\s+/g, " ").trim();
        if (s) parts.push(s);
      });
      // 兜底：没有段落标签结构时取整块
      if (!parts.length) {
        var s = (box.textContent || "").replace(/\s+/g, " ").trim();
        if (s) parts.push(s);
      }
    }
    res[name] = parts;
  });
  return JSON.stringify(res);
})()'
```

### 第 ② 步：直接落盘

```bash
TMP="<临时目录>/raw.json"     # 例：$TEMP / $TMPDIR / /tmp
curl -s -m 20 -X POST "http://localhost:3456/eval?target=$T" -d '...上面的 JS...' -o "$TMP"
```

`-o` 让 curl 直接把响应体写进文件，**不经过模型**。

**注意响应结构**：`/eval` 的返回**包了一层**，形如 `{"value": "<内层 JSON 字符串>"}`。脚本里要解析两次：

```js
const outer = JSON.parse(fs.readFileSync(p, "utf8"));
const data = JSON.parse(outer.value);      // ← 两层
```

**先做一次结构校验**（用 node，不要靠肉眼）：

```bash
"<node 绝对路径>" -e "
const fs = require('fs');
const raw = fs.readFileSync('<临时目录>/raw.json', 'utf8');
console.log('raw bytes:', raw.length);
const d = JSON.parse(JSON.parse(raw).value);
for (const k of Object.keys(d)) {
  console.log(k + ' -> ' + d[k].length + ' paras, ' + d[k].join('').length + ' chars');
}
"
```

这一步能立刻发现「某个键是空的」「段落数异常」，**在生成文档之前拦住**。

### 第 ③ 步：脚本拼装并输出

见下方模板。

---

## 三、可复用脚本模板

保存为临时 `.mjs`，用 node 执行。**把配置区的路径换成你自己的**。

```js
import fs from "fs";

// ---------- 配置区（按实际替换） ----------
const RAW = "<临时目录>/raw.json";
const OUT = "<输出目录>/角色故事-XXX.md";

const TITLE  = "XXX · 角色故事文案";
const SOURCE = "https://<来源页面 URL>";

// 章节顺序 = 输出顺序；key 必须与第①步 want 数组一致
const SECTIONS = [
  ["章节名A", "一、章节名 A"],
  ["章节名B", "二、章节名 B"],
  ["章节名C", "三、章节名 C"],
];
// -----------------------------------------

const data = JSON.parse(JSON.parse(fs.readFileSync(RAW, "utf8")).value);

const lines = [];
lines.push(`# ${TITLE}`);
lines.push("");
lines.push(`> 来源：${SOURCE}`);
lines.push(`> 采集日期：${new Date().toISOString().slice(0, 10)}`);
lines.push(`> 说明：正文按原文逐段导出，未作任何改写。`);
lines.push("");
lines.push("---");
lines.push("");

for (const [key, heading] of SECTIONS) {
  const paras = data[key];
  if (!paras || !paras.length) {
    console.warn("!! 缺失章节: " + key);        // 缺了就报，不要静默跳过
    continue;
  }
  lines.push(`## ${heading}`);
  lines.push("");
  for (const p of paras) lines.push(p, "");      // 空行 = Markdown 段落分隔
}

fs.writeFileSync(OUT, lines.join("\n"), "utf8");
console.log("written: " + OUT + "  (" + fs.statSync(OUT).size + " bytes)");
```

**脚本要点**

- **缺章节要 `console.warn` 报出来**，不要静默 `continue` —— 否则会产出「看起来完整但其实缺一节」的文档
- 每段之间插空行，Markdown 才会正确分段
- 输出编码强制 `"utf8"`

---

## 四、产出后的验收

生成文档后**必须读一遍核对**（用读取工具）。核对四项：

| 检查项 | 怎么判断 |
|---|---|
| **章节齐全** | 对比第①步的 `want` 数组，每节都在 |
| **段落数一致** | 输出段落数 = 第②步校验时打印的段落数 |
| **首尾完整** | 第一节第一段、最后一节最后一段都没有被截断 |
| **段落划分合理** | 没有「两个不相干段落粘在一起」的迹象 |

**把段落数记下来**：第②步校验打印的数字，与第④步读文件时看到的段数应当吻合。**这是发现漏段最直接的证据。**

---

## 五、需要一并处理的三件事

### 1. 非目标但相关的内容

采集时常遇到「高度相关但不属于本次范畴」的条目（例：某个随从角色的独立词条混在角色页面里）。

**原则：要么不收，要么收进「附录」并明确标注其性质。**

```markdown
## 附录：「XXX」词条

> 说明：以下内容**不属于本次采集范畴**，为<具体性质>，因高度相关而一并收录备查。
```

**不要混进正篇**，也不要悄悄丢掉不说。

### 2. 领域术语变体

同一语义位置在不同版本/地区/设定下可能换名（实测案例：角色资料末节，旧体系叫「神之眼」，新体系叫「月之轮」）。

**对策**：**先打印全部候选标题清单**再决定取哪些。

```js
var titles = [];
document.querySelectorAll(".候选标题选择器").forEach(function (t) {
  var s = (t.textContent || "").trim();
  if (s) titles.push(s);
});
return JSON.stringify(titles);
```

**不要凭想象写白名单。**

### 3. 在文档里交代不确定的地方

文档末尾用一段简短说明讲清：术语变体的处理方式、附录的性质、来源的访问条件（是否需要登录）。让后来看文档的人不必回头问。

---

## 六、这套方法能复用到哪些站点

只要目标站点的正文**在 DOM 里**（不管是否可见、是否需要点展开），这套链路就成立。

| 站点类型 | 要点 |
|---|---|
| 社区类文章页（SSR） | `document.body.innerText` 通常直接可取 |
| 百科 / 图鉴类词条 | 折叠面板结构，正文常带 `display:none`，**必须用 `textContent`** |
| 需登录才可见的内容 | 走 CDP（静态层没有登录态） |
| 各类公开文档 | 可先用 curl / Jina 判断能否静态取；能静态取就不必占浏览器 |

**判断顺序**：

```
先试静态（curl / Jina）
        ↓ 拿不到 或 需要登录
   再看 CDP
        ↓ 拿到 DOM
   按本文三段式落盘
```

---

## 七、一句话总结

**模型负责「找到并组织」，不负责「搬运字」。**

凡是要保证逐字准确的文本，都要让它在文件系统里流转，而不是穿过模型。
