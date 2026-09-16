# 执行环境适配

> 目的：Agent 的 shell 执行环境通常**不是**一个完整的开发终端。写命令前先看本文，能省一轮试错。
> 本文是方法论与自检清单，不含任何写死的机器路径 —— **先在你的环境上跑一遍自检**。

---

## 一、先建立正确预期

Agent 执行命令时，常见的情况是：

| 你以为 | 实际常常是 |
|---|---|
| 有完整的 Bash / Git Bash | 只注入了少数必要二进制，**大量基础命令不在 PATH** |
| PowerShell 是最新版 | Windows 上多为 **5.1**，语法受限 |
| 命令输出会正常返回 | **stdout 可能被吞掉**，返回空但没有报错 |
| `node` / `python` 可直接调用 | 托管运行时可能**不在 PATH**，需要绝对路径 |
| 沙箱限制可以用 `--dangerouslyDisableSandbox` 绕过 | 有些失败**与沙箱无关**，绕了也没用 |

**第一条原则：先自检，再写命令。** 不要凭习惯写 shell 管道。

---

## 二、能力自检

进新环境时跑一遍，把结果记下来。

```bash
echo "--- shell tools ---"
for c in node npm python curl git head tail ls grep find sed awk jq mkdir sleep sqlite3; do
  if command -v "$c" >/dev/null 2>&1; then
    echo "OK   $c  ->  $(command -v "$c")"
  else
    echo "MISS $c"
  fi
done
echo "--- versions ---"
node --version 2>&1
curl --version 2>&1 | head -1
```

**如果这个循环本身跑不起来**（因为 `for` / `command` 也不可用），说明 shell 能力极其有限 —— 直接改用 node 内联脚本做探测：

```bash
"/absolute/path/to/node" -e "console.log(process.version, process.platform)"
```

### 重点关注三项

| 检查项 | 为什么重要 | 不满足时 |
|---|---|---|
| **node ≥ 22** | web-access 依赖原生 WebSocket | 装 Node 22+，**这是硬性要求** |
| **node 的绝对路径** | 托管环境常不在 PATH | 记下来，后续调用一律用绝对路径 |
| **shell 工具完整度** | 影响你能否用管道组织命令 | 缺失就走 node 兜底 |

---

## 三、替代写法速查表

**核心思路：需要「逻辑」的时候直接上 node，不要试图用 shell 管道拼。**

| 需求 | ❌ 依赖 shell | ✅ 稳妥写法 |
|---|---|---|
| 等待 N 秒 | `sleep N` | `node -e "setTimeout(function(){},N*1000)"` |
| 截取前 N 行 | `\| head -N` | node 读入后 `split("\n").slice(0,N)` |
| 过滤 / 搜索文本 | `\| grep x` | 文件内容搜索工具；或 node `filter` |
| 遍历目录 | `ls` / `find` | 文件搜索工具；或 node `fs.readdirSync` |
| 创建目录 | `mkdir -p` | node `fs.mkdirSync(p, {recursive:true})` |
| 读文件 | `cat` | 读取文件工具 |
| 写文件 | `echo >` / heredoc | 写文件工具 |
| 改文件 | `sed` / `awk` | 编辑文件工具 |
| 统计（计数/求和） | 管道 + `wc` | node 内联脚本 |
| 解析 JSON | `jq` | node `JSON.parse` |
| 复制 / 移动 / 删除 | `cp` `mv` `rm` | node `fs.copyFileSync` / `renameSync` / `rmSync` |

### 组合示例：一次做完「等待 + 统计 + 落盘」

```bash
"NODE_ABS_PATH" -e '
const fs = require("fs");
// 等待 4 秒
setTimeout(function () {
  const raw = fs.readFileSync("INPUT.json", "utf8");
  const d = JSON.parse(JSON.parse(raw).value);
  for (const k of Object.keys(d)) {
    console.log(k + " -> " + d[k].length + " items");
  }
}, 4000);
'
```

**注意**：`node -e` 的脚本里不要用反引号（会被 shell 解释），用普通引号。

---

## 四、PowerShell 注意事项（Windows）

### 版本

Windows 上多为 **PowerShell 5.1**，**不支持**：`&&`、`||`、三元 `?:`、`??`、`?.`、内联 `if` **表达式**。

```powershell
# ❌ 7+ 才能跑
"$p -> " + (if ($r) { "LISTENING" } else { "closed" })
A && B

# ✅ 5.1 兼容
A; if ($?) { B }
$r = @(Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue)
("port 9222 -> count={0}" -f $r.Count)
```

### stdout 被吞

```powershell
Get-ChildItem "C:\Some" | Select-Object -ExpandProperty Name
# 可能返回空，且没有报错
```

**对策 —— 一律落盘再用读取工具看**：

```powershell
$out = Join-Path $env:TEMP "probe.txt"
"=== section 1 ===" | Out-File -Encoding utf8 $out
Get-ChildItem "C:\Some" -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty Name |
  Out-File -Encoding utf8 -Append $out
```

然后用文件读取工具打开 `%TEMP%\probe.txt`。

**PowerShell 通用探测骨架**：

```powershell
$out = Join-Path $env:TEMP "probe.txt"
function LWT($p) { if (Test-Path $p) { (Get-Item $p).LastWriteTime.ToString("yyyy-MM-dd HH:mm") } else { "MISSING" } }

"=== [1] processes ===" | Out-File -Encoding utf8 $out
Get-Process | Where-Object { $_.ProcessName -match "^(msedge|chrome|node)$" } |
  Group-Object ProcessName | Select-Object Count, Name |
  Format-Table -AutoSize | Out-File -Encoding utf8 -Append $out

"=== [2] ports ===" | Out-File -Encoding utf8 -Append $out
foreach ($p in 9222, 3456) {
  $r = @(Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue)
  ("port {0} -> count={1}" -f $p, $r.Count) | Out-File -Encoding utf8 -Append $out
}
```

### 编码

输出中文时加 `-Encoding utf8`，否则可能乱码。用文件读写工具则无此问题。

---

## 五、浏览器与数据目录的位置

不同系统、不同浏览器，`User Data` 目录位置不同。判断「哪个浏览器在日常使用」时按这个表找：

| 浏览器 | Windows | macOS | Linux |
|---|---|---|---|
| Edge | `%LOCALAPPDATA%\Microsoft\Edge\User Data` | `~/Library/Application Support/Microsoft Edge` | `~/.config/microsoft-edge` |
| Chrome | `%LOCALAPPDATA%\Google\Chrome\User Data` | `~/Library/Application Support/Google/Chrome` | `~/.config/google-chrome` |
| Chromium | `%LOCALAPPDATA%\Chromium\User Data` | `~/Library/Application Support/Chromium` | `~/.config/chromium` |

判据：

- **`Local State`** 的最后修改时间 → 这个浏览器最近是否被使用
- **各 profile 下的 `Network\Cookies`** 的最后修改时间 → 这个 profile 最近是否活跃
  （注意：cookies 在 `Network\` 子目录，**不在 profile 根目录**）
- **`DevToolsActivePort`** 是否存在 → 调试开关是否已生效（**只在开关打开后才生成**）

---

## 六、长驻进程必须后台运行

**这是最重要的一条。** 详见 `ops-pitfalls.md` 的 P-X1。

Agent 的 Bash 工具**通常在命令结束时回收子进程树**。任何需要常驻的进程（CDP proxy、本地服务）都必须以后台任务方式启动：

```bash
node "${CLAUDE_SKILL_DIR}/scripts/cdp-proxy.mjs"
# 以「后台运行、不等待返回」的方式执行
```

启动后**用独立的命令验证**（不要先跑 check-deps）：

```bash
curl -s -m 5 -o /dev/null -w "http=%{http_code}\n" http://localhost:3456/targets
```

`http=200` = 常驻成功。

**判断存活要看端口/进程，不看报错文案** —— 环境自身的出网代理会插入误导性错误（见 P-X2）。

---

## 七、路径规范

**一律使用绝对路径。** 相对路径在 Bash / PowerShell / node 三种上下文里解析基准不一致，容易踩空。

在 Bash 里用**正斜杠**写 Windows 路径也能正确工作：

```bash
"C:/Users/<用户名>/.workbuddy/skills/web-access/scripts/cdp-proxy.mjs"
```

**在 skill 内部引用自身文件**时，用平台提供的 skill 目录变量（WorkBuddy 中为 `${CLAUDE_SKILL_DIR}`，会自动替换为绝对路径）：

```bash
node "${CLAUDE_SKILL_DIR}/scripts/check-deps.mjs"
```

这样 skill 放在哪个目录都能跑 —— **打包分发时必须用这种写法**，不要写死某台机器的路径。

**临时文件**统一放系统临时目录（`%TEMP%` / `$TMPDIR` / `/tmp`），任务收尾时清理。

---

## 八、接入前自检清单

```
□ node 版本 ≥ 22，且已知其绝对路径
□ 浏览器已启动，且用户在浏览器的 inspect 页面勾选了远程调试开关
□ 该页面显示 "Server running at: 127.0.0.1:9222"
□ 调试端口正在监听（9222）
□ DevToolsActivePort 文件已生成
□ proxy 以后台常驻方式启动，日志出现「已连接浏览器 (端口 9222)」
□ curl 3456/targets 返回 200（且此验证前没有跑过 check-deps）
□ 目标站点在 references/site-patterns/ 里有经验文件 → 先读
```

**全绿再开始操作。**

---

## 九、排查口诀

遇到问题时按这个顺序问自己：

1. **它在跑吗？** —— 看端口、看进程，不看文案
2. **我看的是最新的吗？** —— 有没有缓存、有没有跑到旧的 tab、有没有先重载
3. **成功信号可信吗？** —— 接口返回 `ok:true` 只说明「调用发出去了」，不代表「效果发生了」
4. **有没有东西挡在前面？** —— `elementFromPoint` 命中测试
5. **是不是环境的问题？** —— 用 node 内联脚本复现一次，排除 shell 能力不足
