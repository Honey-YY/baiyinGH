# 坑清单完整档案

> 全部条目来自真实部署中的实测，均为**验证过的结论**，不是推测。
> 实测基准：web-access v2.5.4 / Microsoft Edge 153.0.4234.32 / Node.js v22.22.2 / Windows 11。
> 环境相关的条目（尤其 E 类）**先在你的机器上自检**，不同环境的结论可能不同。

---

## 阅读方式

这份文档是**排查入口**，不是必读长文。遇到问题时按现象检索，比顺序通读高效。

级别约定：

- 🔴 **阻塞级** —— 不处理就跑不动
- 🟡 **隐性错误** —— 接口返回成功、实际没生效，最容易被误判为「已完成」
- 🟢 **效率/体验** —— 不影响正确性，但知道能省很多时间

最容易被忽略的是 🟡 类。**工具返回「成功」不等于事情做成了。**

---

# 一、环境类（E）

## P-E1 🔴 执行环境的 shell 能力可能不完备

**现象**

```bash
$ curl -s http://localhost:3456/targets | head -20
bash: head: command not found
```

实测环境中下列命令**均不可用**：`dirname`、`head`、`tail`、`sleep`、`ls`、`grep`、`find`、`findstr`、`wc`、`mkdir`、`sed`、`awk`；`wmic` 被安全策略拉黑。

**根因**

Agent 的 Bash 工具为了隔离与安全，往往只注入必要二进制（`curl`、`git`、`node` 可用），完整 Git Bash 的工具集不在 PATH 里。**这是常见情况，不是异常。**

**对策 —— 先自检，再决定写法**

```bash
for c in head tail sleep ls grep find mkdir sed awk jq node curl git; do
  command -v $c >/dev/null 2>&1 && echo "OK   $c" || echo "MISS $c"
done
```

（若上面的循环本身因缺命令而失败，直接用 `command -v node` 逐个试。）

**替代写法速查**

| 想做的事 | ❌ 别用 | ✅ 改用 |
|---|---|---|
| 等待 N 秒 | `sleep` | `node -e "setTimeout(function(){},N*1000)"` |
| 截取 / 过滤 / 统计 | `head` `grep` `wc` | node 内联脚本 |
| 遍历目录 | `ls` `find` | 文件搜索工具，或 node `fs.readdirSync` |
| 创建目录 | `mkdir` | node `fs.mkdirSync(p, {recursive:true})` |
| 读 / 写 / 改文件 | `cat` `echo >` `sed` | Read / Write / Edit 工具 |
| 解析 JSON | `jq` | node `JSON.parse` |

**关键教训**：需要「逻辑」的时候直接上 node 内联脚本，不要试图用 shell 管道拼。**用 node 的绝对路径调用**（见 P-E2）。

---

## P-E2 🔴 node 用绝对路径调用；PowerShell 有版本与输出限制

**现象 A —— node 可能不在 PATH**

即使 `node --version` 能跑，用绝对路径调用仍更可靠（某些托管运行时不在 PATH 中）。

**现象 B —— Windows PowerShell 是 5.1**

```powershell
# 这样写直接报错（PowerShell 7+ 才有）
"$p -> " + (if ($r) { "LISTENING" } else { "closed" })
```

5.1 **不支持**：`&&`、`||`、三元 `?:`、null 合并 `??`、null 条件 `?.`、内联 `if` **表达式**。

**现象 C —— 输出丢失**

`Get-ChildItem ... | Select-Object Name` 这类命令执行后**返回空**，没有报错。不是命令失败，是 stdout 被吞了。

**对策**

先用 `command -v node` 或 `where node` 拿到 node 的**绝对路径**，之后的调用一律用绝对路径：

```bash
"/absolute/path/to/node" -e "console.log('ok')"
```

PowerShell 统一走「`Out-File` 落盘 → 用读取工具读」：

```powershell
$out = Join-Path $env:TEMP "probe.txt"
"=== section 1 ===" | Out-File -Encoding utf8 $out
Get-Process | Where-Object { $_.ProcessName -match "^(msedge|node)$" } |
  Select-Object Id, ProcessName |
  Format-Table -AutoSize |
  Out-File -Encoding utf8 -Append $out
```

**5.1 兼容写法**

```powershell
# 条件串联
A; if ($?) { B }
# 替代内联 if：用数组计数 + 格式化
$r = @(Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue)
("port 9222 -> count={0}" -f $r.Count)
```

---

## P-E3 ⚪ 虚警：`${CLAUDE_SKILL_DIR}` 是否可用

**疑虑**：SKILL.md 里所有脚本调用都写成 `node "${CLAUDE_SKILL_DIR}/scripts/check-deps.mjs"`，这是 Claude Code 的变量。别的 Agent 平台会不会不替换？

**实测结论：在 WorkBuddy 中会被自动替换为绝对路径，无需手动改写。**

**这条只在首次调用时验证一次** —— 如果第一次调用报「找不到路径」，就把相关位置换成绝对路径。属于「有备无患」而非「必须处理」。

**如果你在其他平台遇到此问题**：把路径改成该平台的 skill 目录变量，或直接写绝对路径。

---

# 二、浏览器接入类（C）

## P-C1 🔴 浏览器未开远程调试开关

**现象**

```
node:    ok (v22.x.x)
config:  已创建 config.env
browser: 未连接 — 没有任何浏览器打开远程调试开关
```

`check-deps.mjs` 以 **exit 1** 退出。

**根因**

Chromium 系浏览器的远程调试默认关闭，且**设计上不允许程序静默开启**（防止恶意软件劫持浏览器）。必须由用户在界面里手动勾选。

**对策 —— 由用户手动完成**

| 浏览器 | 地址 |
|---|---|
| Edge | `edge://inspect/#remote-debugging` |
| Chrome | `chrome://inspect/#remote-debugging` |

勾选 "Allow remote debugging for this browser instance"。

**这是 Agent 无法代劳的一步。** 不要试图用命令行 `--remote-debugging-port` 绕过（见 P-C5）。

---

## P-C2 🔴 漏掉 `#remote-debugging` 锚点 → 页面上没有那个开关

**现象**

用户说「已经开了」，但 Agent 侧三条验证全不过。

**根因**

用户只输入了 `edge://inspect`，落到的是**设备列表页**，那个位置**没有** "Allow remote debugging" 复选框。必须带 `#remote-debugging` 锚点才会进到正确的面板。

**对策**

指引必须写成完整的 `edge://inspect/#remote-debugging`，并明确告知**成功标志**：

```
Server running at: 127.0.0.1:9222
```

**关键教训**：让用户操作的步骤，不要只给动作，**要给可验证的成功标志**。用户以为自己完成了、实际没完成，是这类问题的常态。反复说「已经开了」而没有看到那行字，就继续引导，不要往下走。

---

## P-C3 🟡 调试端口的 404 不等于「没开」

**现象**

```bash
$ curl -s http://127.0.0.1:9222/json/version
http=404
```

看起来像没开。

**根因**

新版 Chromium 收紧了 `/json/*` 发现接口，对本地探测返回 404。**但端口本身是正常的**，proxy 会改走 `ws://127.0.0.1:9222/devtools/browser`（带 wsPath）。

**对策**

判断调试端口是否可用，看**端口监听**与**端口文件**，不看 `/json/version` 的返回值：

```powershell
# 端口监听
$r = @(Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue)
("9222 -> count={0}" -f $r.Count)

# 端口文件（Windows，注意用户名与浏览器名）
Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\DevToolsActivePort"
Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\DevToolsActivePort"
```

macOS：`~/Library/Application Support/Microsoft Edge/User Data/DevToolsActivePort`
Linux：`~/.config/microsoft-edge/DevToolsActivePort`

---

## P-C4 🟢 浏览器选型要看数据活跃度，不是「装没装」

**现象**

默认按 Chrome 走，后发现该机器上 Chrome 虽然装了、数据却陈旧；真正日常用的是 Edge。

**判据（实测有效）**

| 浏览器 | 实际情况 |
|---|---|
| Chrome | User Data 存在，但程序不在常规安装路径；`Local State` 停在一个半月前 |
| Edge | 装在常规路径；`Default` profile 的 cookies **当天仍在更新** |

**对策 —— 选之前先看活跃度证据**

```powershell
# 各浏览器的 User Data 最后写入时间
$browsers = @(
  @{n="Edge";   p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
  @{n="Chrome"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"}
)
foreach ($b in $browsers) {
  if (Test-Path $b.p) {
    "$($b.n)  LocalState=" + (Get-Item "$($b.p)\Local State").LastWriteTime
    Get-ChildItem $b.p -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match "^(Default|Profile)" } |
      ForEach-Object {
        $c = Join-Path $_.FullName "Network\Cookies"
        if (Test-Path $c) { "  $($_.Name)  cookies=" + (Get-Item $c).LastWriteTime }
      }
  }
}
```

> **注意**：Chromium 系浏览器的 cookies 在 `Network\Cookies`，**不在 profile 根目录**。

**另一个坑**：`DevToolsActivePort` 只在**开关打开后**才生成。它不存在、而浏览器进程在跑，说明**开关没生效**，不是浏览器没启动。

---

## P-C5 🟢 免授权的独立实例方案（备选，有代价）

**背景**

Chromium 136 之后有安全限制：**`--remote-debugging-port` 配默认用户目录会被静默忽略**。想从命令行直开调试端口，必须同时指定一个全新的 `--user-data-dir`。

**效果**：完全不需要任何浏览器授权，一劳永逸。

**代价**：那是一个全新的浏览器实例，**独立 profile，所有站点的登录态都要重新登录一次**。

**何时选它**：需要长期、高频、无人值守地跑自动化。
**何时不选**：一次性任务，且目标站点登录态在现有浏览器里。

---

## P-C6 🔴 外部浏览器 CLI 静默 `exit 69`：集成本身坏了

**现象（案例）**

某浏览器 CLI 三次调用全部**静默退出 exit 69，零输出**：

1. 沙箱内
2. 关闭沙箱后（排除沙箱因素）
3. 固定实例 ID 后

正常的 CLI 失败一定会打印原因。**零输出的退出码 = 路由彻底失败**，不是权限问题。

**根因**

集成记录指向**不存在的路径**：

```
实例记录里的 cliPath → ...\Application\1.13.24.0\TabbitDance\...-cli.exe
实际安装目录         → ...\Application\1.6.20.0
```

推测该浏览器被降级或换渠道重装过，旧记录未清理。

**另有一个干扰项**：机器上存在同一浏览器的**两个安装** —— 一个活跃但当时未运行，另一个有进程在跑却完全没有集成（无 CLI、无集成目录）。有进程 ≠ 能接入。

**对策**

官方解法是**重启一次有效的那个安装，让它自己重建托管集成记录**。此类 skill 通常明确禁止手工改注册表、改路径或自行启动 Runtime Service。

**这属于安装层损坏，Agent 无法自行修复。** 启动 GUI 进程需用户许可，且重建后仍需确认登录态 —— 直接向用户说明并请他决定，不要硬试。

**通用教训**：外部 CLI 的 `exit 69`（`EX_UNAVAILABLE`）+ 零输出，优先怀疑**集成记录/路由失效**，而不是权限或沙箱。

---

# 三、Proxy 类（X）

## P-X1 🔴🔴 Proxy 每条命令被重启 → 反复要求浏览器授权

**部署中影响体验最大的问题。**

**现象**

用户每做一步操作，都要在浏览器里点一次授权确认。

**根因**

SKILL.md 明确写着：

> Proxy 持续运行，不建议主动停止——**重启后需要在浏览器中重新授权 CDP 连接**。

而 Agent 的 Bash 工具**通常在每条命令结束时回收整个子进程树**。若写成：

```bash
node check-deps.mjs    # ← 这一句把 proxy 拉起来
curl http://localhost:3456/xxx
# ← 命令结束，proxy 随进程树被回收
```

下一轮再跑 `check-deps` → 再拉一次 → 又被回收……**等于每条命令重启一次 proxy**，每轮都要用户重新授权。

**证据链**

- 单独执行 `curl http://localhost:3456/targets` → 失败
- 先跑 `check-deps.mjs` 再 curl → 成功
- 中途不跑 check-deps，3456 就没人应答

**对策**

以后台任务方式启动 proxy，让它脱离命令生命周期：

```bash
node "${CLAUDE_SKILL_DIR}/scripts/cdp-proxy.mjs"
# 以 run_in_background = true 执行（或等价的「不等待返回」方式）
```

**验证方法**：**不要再跑 check-deps**，直接

```bash
curl -s -o /dev/null -w "http=%{http_code}\n" http://localhost:3456/targets
```

返回 `http=200` 说明它跨命令存活了。

**效果**：一次授权，整个浏览器会话内复用。

**注意**：浏览器关闭后调试端口消失，需重新开关 + 授权一次。

---

## P-X2 🟡 `upstream connect failed ... os error 10061` 是误导信息

**现象**

proxy 未运行时，`curl http://localhost:3456/xxx` 返回的不是预期的 `Connection refused`，而是：

```
upstream connect failed: 由于目标计算机积极拒绝，无法连接。(os error 10061)
```

容易让人以为 proxy 内部出了问题。

**根因**

这是**执行环境自身的出网代理**转发的报错，跟 web-access skill 无关。

**验证**：全目录搜索过，该字符串**不在 skill 源码里**。

**对策**

看到这句话不要去 skill 里翻源码。它就是「3456 没人监听」的另一种说法。

---

## P-X3 🟡 判断 proxy 死活要用端口/进程证据

**错误做法**：看 curl 的返回文案，或靠猜。

**正确做法**：

```powershell
$r = @(Get-NetTCPConnection -LocalPort 3456 -State Listen -ErrorAction SilentlyContinue)
("3456 -> count={0}" -f $r.Count)
Get-Process node -ErrorAction SilentlyContinue | Select-Object Id, Path
```

或更直接：

```bash
curl -s -m 5 -o /dev/null -w "http=%{http_code}\n" http://localhost:3456/targets
```

**看 HTTP 状态码，不看报错文案。**

---

# 四、页面操作类（O）

## P-O1 🟡 `clickAt` / `click` 只作用于第一个匹配元素

**现象**

```
=== CLICK .mhy-heart-click ===
{"ok":true,"x":520,"y":366}
=== AFTER ===
（目标计数毫无变化）
```

返回坐标和 Agent 量到的位置对不上。

**根因**

同一类名在页面上有 **27 个**（目标元素 1 个 + 评论区每条留言各 1 个）。`clickAt` 取的是**文档顺序第一个**，也就是评论区里的那个。

**对策**

```js
// 先数
document.querySelectorAll(".某类名").length                        // → 27
// 加作用域
document.querySelectorAll(".父容器 .某类名").length                  // → 1
```

**通用规范**：**操作前先 `querySelectorAll(sel).length`，大于 1 就加作用域前缀。**

---

## P-O2 🟡 `/click` 的 JS 合成事件会被站点忽略

**现象**

`/click` 返回成功，页面状态不变。

**根因**

`/click` 走的是 JS `el.click()`，产生的事件 `isTrusted = false`。**部分站点（尤其有风控的社区站）会过滤非受信事件。**

**对策**

改用 `/clickAt`（走 CDP `Input.dispatchMouseEvent`，真实鼠标事件，算用户手势）。

**注意**：`/clickAt` 的坐标由**元素选择器**推导，不是让你传坐标 —— 所以 P-O1 的作用域问题同样适用。

---

## P-O3 🟡 顶部计数条是只读展示，不是按钮

**现象**

点了页面顶部信息栏里的「点赞」数字，毫无反应。

**根因**

顶部信息栏只是**数字展示**，没有绑定点击。真正的交互入口在左侧竖排浮动栏。

**对策**

不要按「哪里显示点赞数，哪里就是点赞按钮」推断。**用结构定位**：找到承载交互行为的容器（通常带 `actions` / `toolbar` / `interactive` 之类语义），再在其内部找按钮。

---

## P-O4 🟡 登录/弹窗浮层全屏遮挡，点击全部失效

**现象**

`/clickAt` 返回坐标正确、状态不变。

**诊断过程（关键手法）**

```js
document.elementFromPoint(213, 296)
// → <iframe src="https://...login-platform/index.html?...">
//   BODY.mhy-login-platform__overflow
```

**根因**

需要登录的交互会拉起登录平台，以**全视口 iframe** 覆盖页面，同时给 `<body>` 加上遮罩类。此后 `elementFromPoint(x,y)` 恒返回 `IFRAME`，**任何鼠标点击都打不到页面元素**。

**对策**

1. **点击前先做命中测试**：`document.elementFromPoint(x,y).tagName`，返回 `IFRAME` 就先处理遮挡
2. 也可看 `document.body.className` 是否含 `login` / `modal` / `mask` 之类关键词
3. 关闭：派发 Escape

```js
document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", keyCode: 27, bubbles: true }))
```

实测有效：`body` 的遮罩类被移除，命中元素恢复成按钮本身。

**这是「点击无效」排查的第一步，顺序不能反** —— 跳过它直接改选择器，会在错误的方向上绕很久。

---

## P-O5 🟡 站点可能没有「已操作」的视觉状态

**现象**

写操作成功了（计数 +1），但图标颜色始终是灰色，没有任何「已赞」高亮。差点判定为失败。

**根因**

扫描该页 **187 个 stylesheet**，含目标按钮类名的规则只有三条（cursor、display、评论区的 font-size / color），**没有任何 active / liked / selected 样式**。图标的 computed fill 恒定不变。

即：**这个布局压根没做已操作态的视觉反馈。**

**对策 —— 验证方式改为「服务端证据」**

1. 读容器文本形式的计数
2. **重新 navigate 同一 URL 重载**，确认服务端返回的也是新计数

计数更新是异步的，点击后等 3–5 秒再读。

**通用教训**：**不要假设站点一定有状态样式。** 想知道写操作是否生效，优先找「服务端持久化的证据」（计数、列表项、接口响应），而不是 UI 状态。

---

## P-O6 🟡 `display:none` 元素上 `innerText` 不可靠

**现象**

找到了正文容器，但 `innerText` 取出来是空。

**根因**

容器带 `display:none`（未展开状态）。`innerText` 依赖布局计算，不可见元素取不到；`textContent` 不管可见性，直接读 DOM 文本节点。

**对策**

```js
box.textContent   // ← 用这个
box.innerText     // ← 不要用
```

**顺带的好处**：内容本来就在 DOM 里，**完全不用点「展开」也能取到全文**，省掉所有展开交互。

详见 `ops-capture-fidelity.md`。

---

## P-O7 🟡 受控输入框直接赋值 `value` 无效

**现象**

```js
inp.value = "关键词"      // 无效，搜索不触发
```

**根因**

Vue / React 受控组件监听的是框架内部状态，直接改 DOM `value` 不触发它的更新。

**对策 —— 原生 setter + 派发事件**

```js
var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
setter.call(inp, "关键词");
inp.dispatchEvent(new Event("input",  { bubbles: true }));
inp.dispatchEvent(new Event("change", { bubbles: true }));
inp.focus();
```

输入后等约 2.5 秒出现候选。**拿到候选链接后建议直接用 href 导航，比点候选更稳。**

---

## P-O8 🟡 按语义猜类名不可靠

**现象**

用 `/like|praise|upvote|vote|thumb|support|zan/i` 扫类名，扫出来的全是**顶部的只读计数条**，真正的按钮一个没匹配到。

**根因**

真正的按钮类名是 `.mhy-heart-click`（**heart**，不是 like/zan）。语义命中的词表覆盖不到。

**对策**

**用结构定位，不用语义猜。** 有效路径：

1. **先截图看页面实际布局**，确认目标在哪个区域（这是最快的一步）
2. 按**几何位置**筛选元素：

```js
document.querySelectorAll("div,span,button,a,i").forEach(function (el) {
  var r = el.getBoundingClientRect();
  if (r.width > 0 && r.height > 0 && r.x < 210 && r.x > 60 && r.y > 60 && r.y < 520) {
    // 该区域内的可见元素
  }
});
```

**教训**：截图是定位 UI 元素最有效的第一步，比穷举类名词表快得多。

---

## P-O9 🟢 fixed 侧栏坐标不随滚动变化

**现象**

页面滚动很远之后，量到的按钮坐标仍与初始一致，与直觉（应该往上跑）不符。

**根因**

目标元素在 `position: fixed` 的浮动栏里，**永远吸附在视口固定位置**。

**对策**

知道这点就不用反复重算坐标。反过来：**`/scroll` 不会改变 fixed 元素的视口坐标**，点击前若滚动过，坐标不必重测。

---

# 五、采集类（D）

## P-D1 🟡 领域术语陷阱：同一语义位置换了名字

**现象**

按某个字段名匹配，**一无所获**。

**根因（案例）**

角色资料页的「角色故事」体系末节，旧内容体系里叫「神之眼」，新内容体系里改叫「月之轮」。只匹配前者会漏掉整节。

**对策**

1. **先打印全部候选标题清单**，再决定取哪些 —— 不要凭想象写白名单：

```js
var titles = [];
document.querySelectorAll(".候选标题选择器").forEach(function (t) {
  var s = (t.textContent || "").trim();
  if (s) titles.push(s);
});
return JSON.stringify(titles);
```

2. 已知存在变体的字段，**把多个候选名一起覆盖**。

这类术语变体在游戏、文化、行业类站点很常见（同一语义位置换了套设定名词，尤其跨版本、跨地区时）。

---

## P-D2 🟡 模糊匹配会把非目标内容混进正文

**现象**

按「包含某关键词」这类模糊规则筛，会把并非目标的内容也捞进来。

**根因**

标题里存在**看似相关但不属于本次范畴**的条目（同一页面常有 CV、料理、邮件、关联角色等多个面板）。

**对策**

- **按标题白名单精确匹配**（全等比较或 `indexOf(name) >= 0`），不用模糊正则
- 对「相关但不是同一范畴」的内容（例如某随从角色的独立词条），**要么不收，要么收进附录并明确标注其性质**

---

## P-D3 🟡 让模型转写正文 = 改写/漏段风险

**风险**

如果把网页正文「读进上下文再打出来」，模型会在长文本上发生：**漏段、段落合并、同义替换、标点规范化**。

**根因**

模型生成是概率采样，**长文本逐字复制不是它的可靠能力**。任务要求「原文不得改写」时，这是根本性冲突，不是「小心一点」能解决的。

**对策 —— 保真采集三段式**

```
① /eval      → 页面返回 JSON 字符串（逐段 textContent）
② curl -o    → 直接落盘成临时文件（内容不进入模型上下文）
③ .mjs 脚本  → 读临时文件 → 拼 Markdown → 输出
```

文字从页面到文件**全程逐字传递，零模型转述**。

完整实现（含可复用脚本模板与验收标准）见 `ops-capture-fidelity.md`。

---

# 六、流程与边界类（G）

## P-G1 🔴 社交写操作必须先确认范围

**问题**

点赞 / 关注 / 收藏在社区站都绑定真实账号。**关注尤其严重**：会通知对方作者，并永久留在公开关注列表里，**不可撤销**。

**另一面**：脚本化社交互动是各平台风控的重点打击对象。「随机找一篇文章点赞+关注+收藏」在风控模型里就是刷量机器人的典型特征。

**对策 —— 动手前必须做的三件事**

1. **展示上游内置的强制提示语**（SKILL.md 要求）：

   > 温馨提示：部分站点对浏览器自动化操作检测严格，存在账号封禁风险。已内置防护措施但无法完全避免，Agent 继续操作即视为接受。

2. **用选项让用户明确划定范围**。例如「只读验证 / 只点赞一篇 / 三个全做」三档，并如实说明每档的代价（关注会通知对方等）。

3. **指出投入产出**：如果用户的真实目的是验证工具链路，只读 + 单次写操作足以覆盖 CDP 连接、登录态识别、动态渲染、真实鼠标事件、写操作验证 —— **不必把更不可逆的操作搭进去**。

**这不是「不配合」，是把用户没意识到的不可逆代价提前说清。**

---

## P-G2 🟡 计数型指标有并发干扰，结论必须标注不确定性

**现象**

点赞计数持续上升。但**无法 100% 断定这次变化全部来自自己的操作** —— 热门内容（官方活动帖等）的基数随时在涨。

**对策**

- 结论里**如实标注不确定性**，不要报成「确认成功 +N」
- 降低干扰：选**冷门内容**（基数稳定）
- 更强的证据：重载后服务端计数一致（说明确实持久化），但仍不能排除并发

**原则**：**不把「观察到计数变化」夸大成「确认是我的操作生效」。**

---

## P-G3 🟢 静态抓取层没有登录态，写操作必须走 CDP

**事实（实测）**

社区类站点公开页面**通常可以静态抓取**：

```
https://<站点>/<板块>/    http=200  bytes≈100KB   ← SSR 渲染，不是空壳
Jina Reader                http=200  bytes≈33KB
```

但抓到的页面里账号链接形如：

```
.../accountCenter/postList?id=undefined      ← 游客视角
```

**对策 —— 按任务性质分流，省 token 也省时间**

| 环节 | 通道 |
|---|---|
| 读列表、读正文 | ✅ 静态（curl / Jina）通常即可 |
| 写操作（点赞/收藏/关注/评论/投稿） | ❌ 必须 CDP + 真实登录态 |

**登录判据不要看 cookie**：许多站点**未登录也会写入一批设备/访客标识 cookie**，看起来像登录了；真正的鉴权 cookie 是 `httpOnly`，脚本读不到。

**可靠判据**：页头头像 `<img>` 的 src —— 已登录是真实上传头像，未登录是默认图（如 `avatarDefault*`）。

---

## 附：一次完整部署的问题时间线（供复盘）

```
安装 skill → 安全审计（通读全部脚本）
                        ↓
              尝试外部浏览器 CLI → exit 69 三次 → 放弃（P-C6）
                        ↓
              切 Chrome/Edge CDP → 开关两次才生效（P-C1/C2）
                        ↓
              页面写操作 → 选择器错→遮挡层→无状态样式（P-O1/O3/O4/O5）
                        ↓
              用户反馈「每步都要授权」→ 定位 proxy 重启（P-X1）→ 常驻化
                        ↓
              文本采集 → 术语陷阱 + 保真三段式（P-D1/D3）
                        ↓
              沉淀本文
```

**这条时间线的启示**：真正拖慢进度的不是「不知道怎么做」，而是 **🟡 类隐性错误**（返回成功但没生效）。排查时优先问自己：**我凭什么认为这一步成功了？**
