#!/usr/bin/env node
/**
 * 生成用于 GitHub Release 的分发压缩包
 *
 * 用法:
 *   node tools/build-release.mjs
 *
 * 输出:
 *   dist/web-access-skill-v<版本号>.zip
 *
 * 说明:
 *   本仓库是「一个 skill 一个仓库」结构 —— 仓库根目录即技能本体。
 *   因此打包时要反过来做一件事：把根目录的技能文件**装进一个 web-access/ 文件夹**，
 *   这样读者解压后可直接把 web-access/ 拖进 skills 目录（技能名必须与 SKILL.md 的 name 一致）。
 *
 *   仓库自身的管道文件（tools/、install 脚本、package.json、.git* 等）不进包。
 */

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const DIST_DIR = path.join(ROOT, 'dist');

const SKILL_NAME = 'web-access';          // 包内顶层文件夹名 = SKILL.md 的 name
const RELEASE_NAME = 'web-access-skill';  // 包名与 GitHub 仓库名一致

// ---------- 技能文件清单（不含仓库管道文件） ----------
const INCLUDE = [
  'SKILL.md',
  'INSTALL.md',
  'README.md',
  'LICENSE',
  'references',
  'scripts',
  'templates',
];

// ---------- 本机标识泄漏扫描 ----------
// 注意：不要用「C:\Users\」这种宽泛关键词 —— 文档里的 C:\Users\<用户名> 是给读者的占位符，属正常内容。
// 只匹配本机独有的标识。
const LEAK_MARKERS = ['q2101', 'AI' + '工作台', 'Tabbit Browser', 'PortableGit'];
const TEXT_EXT = ['.md', '.mjs', '.js', '.json', '.sh', '.ps1', '.template', '.txt', '.env'];

// ---------- 读版本号 ----------
const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
const VERSION = pkg.version;
const OUT = path.join(DIST_DIR, `${RELEASE_NAME}-v${VERSION}.zip`);

console.log('构建分发包');
console.log('  仓库根目录: ' + ROOT);
console.log('  技能名    : ' + SKILL_NAME + '（包内顶层文件夹）');
console.log('  版本号    : v' + VERSION);
console.log('');

// ---------- 前置校验：技能定义必须存在且 name 一致 ----------
const skillMdPath = path.join(ROOT, 'SKILL.md');
if (!fs.existsSync(skillMdPath)) {
  console.error('错误: 仓库根目录缺少 SKILL.md —— 本仓库应为「根目录即技能」结构。');
  process.exit(1);
}
const skillMd = fs.readFileSync(skillMdPath, 'utf8');
const nameMatch = skillMd.match(/^name:\s*(\S+)/m);
if (!nameMatch || nameMatch[1] !== SKILL_NAME) {
  console.error('错误: SKILL.md 的 name 字段为「' + (nameMatch ? nameMatch[1] : '未找到') +
    '」，与包内文件夹名「' + SKILL_NAME + '」不一致。');
  process.exit(1);
}
console.log('前置校验: SKILL.md 存在，name = ' + nameMatch[1] + ' ✓');
console.log('');

// ---------- 组装暂存目录 ----------
const stageRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'waskill-'));
const stageSkill = path.join(stageRoot, SKILL_NAME);
fs.mkdirSync(stageSkill, { recursive: true });

const collected = [];
function copyInto(rel) {
  const src = path.join(ROOT, rel);
  if (!fs.existsSync(src)) {
    console.error('  [警告] 清单中不存在: ' + rel);
    return;
  }
  const dst = path.join(stageSkill, rel);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.cpSync(src, dst, {
    recursive: true,
    filter: (s) => path.basename(s) !== 'config.env',   // 本机偏好文件，绝不进包
  });
  const walk = (p) => {
    if (fs.statSync(p).isDirectory()) {
      fs.readdirSync(p).forEach((f) => walk(path.join(p, f)));
    } else {
      collected.push(path.relative(stageSkill, p));
    }
  };
  walk(dst);
}

console.log('装配包内文件:');
INCLUDE.forEach((r) => { copyInto(r); console.log('  + ' + r); });
console.log('');

collected.sort();

// ---------- 泄漏扫描 ----------
const leaks = [];
for (const rel of collected) {
  const ext = path.extname(rel).toLowerCase();
  if (!TEXT_EXT.includes(ext)) continue;
  const text = fs.readFileSync(path.join(stageSkill, rel), 'utf8');
  for (const m of LEAK_MARKERS) {
    if (text.includes(m)) leaks.push(rel + '  ← 命中「' + m + '」');
  }
}

// ---------- 打包 ----------
fs.rmSync(DIST_DIR, { recursive: true, force: true });
fs.mkdirSync(DIST_DIR, { recursive: true });

const tarCandidates = ['C:/Windows/System32/tar.exe', '/usr/bin/tar', '/bin/tar', '/usr/local/bin/tar'];
let tar = 'tar';
for (const c of tarCandidates) {
  if (fs.existsSync(c)) { tar = c; break; }
}

try {
  execFileSync(tar, ['-c', '-f', OUT, '--format=zip', '-C', stageRoot, SKILL_NAME],
    { stdio: ['ignore', 'pipe', 'pipe'] });
} catch (err) {
  console.error('打包失败: ' + err.message);
  fs.rmSync(stageRoot, { recursive: true, force: true });
  process.exit(1);
}
fs.rmSync(stageRoot, { recursive: true, force: true });

// ---------- 解析 zip 中央目录做校验 ----------
const buf = fs.readFileSync(OUT);
const names = [];
for (let i = 0; i < buf.length - 4; i++) {
  if (buf.readUInt32LE(i) === 0x02014b50) {
    const nlen = buf.readUInt16LE(i + 28);
    names.push(buf.toString('utf8', i + 46, i + 46 + nlen));
  }
}
const files = names.filter((n) => !n.endsWith('/'));
const badPath = names.filter((n) => n.includes('\\'));
const leaked = names.filter((n) => n.endsWith('config.env'));
const wrongTop = names.filter((n) => !n.startsWith(SKILL_NAME + '/'));
const hasSkillMd = files.includes(SKILL_NAME + '/SKILL.md');
const hasLicense = files.includes(SKILL_NAME + '/LICENSE');

const sha256 = crypto.createHash('sha256').update(buf).digest('hex').toUpperCase();
const size = buf.length;

console.log('打包完成');
console.log('  输出  : ' + OUT);
console.log('  大小  : ' + size + ' 字节');
console.log('  SHA256: ' + sha256);
console.log('');
console.log('校验:');
console.log('  条目总数          : ' + names.length);
console.log('  文件数            : ' + files.length);
console.log('  顶层文件夹        : ' + (wrongTop.length === 0 ? '全在 ' + SKILL_NAME + '/ 下 ✓' : '✗ ' + wrongTop.length + ' 项越出顶层目录'));
console.log('  SKILL.md 在第一层 : ' + (hasSkillMd ? '✓' : '✗'));
console.log('  LICENSE 已包含    : ' + (hasLicense ? '✓（MIT 条款要求随副本分发）' : '✗ 缺失'));
console.log('  反斜杠路径        : ' + badPath.length + ' (应为 0，跨平台安全)');
console.log('  config.env 混入   : ' + leaked.length + ' (应为 0)');
console.log('  本机标识泄漏      : ' + leaks.length + ' (应为 0)');
if (leaks.length) leaks.forEach((l) => console.log('      - ' + l));

const failed = badPath.length || leaked.length || leaks.length || wrongTop.length || !hasSkillMd || !hasLicense;
if (failed) {
  console.error('');
  console.error('校验未通过。');
  process.exit(1);
}

console.log('');
console.log('下一步: 到 GitHub 仓库的 Releases 页面新建 Release，');
console.log('        打上标签 v' + VERSION + '，把上面这个 zip 作为附件上传。');
