#!/usr/bin/env node
/**
 * 生成用于 GitHub Release 的分发压缩包
 *
 * 用法:
 *   node scripts/build-release.mjs
 *
 * 输出:
 *   dist/ai-skill-library-v<版本号>.zip
 *
 * 说明:
 *   压缩包内每个技能文件夹位于根层，读者解压后可直接拖进 skills 目录。
 */

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SKILLS_DIR = path.join(ROOT, 'skills');
const DIST_DIR = path.join(ROOT, 'dist');

// ---------- 读版本号 ----------
const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
const VERSION = pkg.version;
const OUT = path.join(DIST_DIR, `${pkg.name}-v${VERSION}.zip`);

console.log('构建分发包');
console.log('  仓库根目录: ' + ROOT);
console.log('  版本号    : v' + VERSION);
console.log('');

// ---------- 收集技能 ----------
if (!fs.existsSync(SKILLS_DIR)) {
  console.error('错误: 找不到 skills 目录。');
  process.exit(1);
}

const skills = fs.readdirSync(SKILLS_DIR, { withFileTypes: true })
  .filter(e => e.isDirectory())
  .map(e => e.name)
  .sort();

if (skills.length === 0) {
  console.error('错误: skills 目录下没有任何技能。');
  process.exit(1);
}

// ---------- 校验每个技能都有 SKILL.md ----------
let hasError = false;
for (const s of skills) {
  if (!fs.existsSync(path.join(SKILLS_DIR, s, 'SKILL.md'))) {
    console.error('  [警告] ' + s + ' 缺少 SKILL.md，可能无法被识别');
    hasError = true;
  }
}
if (hasError) {
  console.error('');
  console.error('存在缺少 SKILL.md 的技能，请先补齐。');
  process.exit(1);
}

console.log('待打包技能 (' + skills.length + ' 个):');
skills.forEach(s => console.log('  - ' + s));
console.log('');

// ---------- 清理 dist ----------
fs.rmSync(DIST_DIR, { recursive: true, force: true });
fs.mkdirSync(DIST_DIR, { recursive: true });

// ---------- 挑选 tar（优先 bsdtar，生成 POSIX 分隔符的 zip） ----------
const candidates = [
  'C:/Windows/System32/tar.exe',
  '/usr/bin/tar',
  '/bin/tar',
  '/usr/local/bin/tar',
];
let tar = 'tar';
for (const c of candidates) {
  if (fs.existsSync(c)) { tar = c; break; }
}

// ---------- 打包 ----------
try {
  execFileSync(tar, [
    '-c', '-f', OUT, '--format=zip',
    '--exclude=config.env',
    '--exclude=.git',
    '-C', SKILLS_DIR,
    ...skills,
  ], { stdio: ['ignore', 'pipe', 'pipe'] });
} catch (err) {
  console.error('打包失败: ' + err.message);
  process.exit(1);
}

const size = fs.statSync(OUT).size;

// ---------- 解析 zip 条目做校验 ----------
const buf = fs.readFileSync(OUT);
const names = [];
for (let i = 0; i < buf.length - 4; i++) {
  if (buf.readUInt32LE(i) === 0x02014b50) {
    const nlen = buf.readUInt16LE(i + 28);
    names.push(buf.toString('utf8', i + 46, i + 46 + nlen));
  }
}
const files = names.filter(n => !n.endsWith('/'));
const badPath = names.filter(n => n.includes('\\'));
const leaked = names.filter(n => n.endsWith('config.env'));

console.log('打包完成');
console.log('  输出: ' + OUT);
console.log('  大小: ' + size + ' 字节');
console.log('');
console.log('校验:');
console.log('  条目总数        : ' + names.length);
console.log('  文件数          : ' + files.length);
console.log('  反斜杠路径      : ' + badPath.length + ' (应为 0，跨平台安全)');
console.log('  config.env 混入 : ' + leaked.length + ' (应为 0)');

if (badPath.length || leaked.length) {
  console.error('');
  console.error('校验未通过。');
  process.exit(1);
}

console.log('');
console.log('下一步: 到 GitHub 仓库的 Releases 页面新建 Release，');
console.log('        打上标签 v' + VERSION + '，把上面这个 zip 作为附件上传。');
