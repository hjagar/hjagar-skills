import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  validateSkillName,
  buildAgentPaths,
  copySkill,
  writeKiroSteering,
} from '../lib/skill-payload.mjs';

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'hjagar-payload-'));
}

function makeSkill(root, name, { crlf = false, extraDirs = [] } = {}) {
  const dir = path.join(root, name);
  fs.mkdirSync(dir, { recursive: true });
  const eol = crlf ? '\r\n' : '\n';
  fs.writeFileSync(path.join(dir, 'SKILL.md'), `---${eol}name: ${name}${eol}---${eol}body${eol}`);
  for (const d of extraDirs) {
    fs.mkdirSync(path.join(dir, d), { recursive: true });
    fs.writeFileSync(path.join(dir, d, 'f.txt'), d);
  }
  return dir;
}

test('validateSkillName accepts kebab names and rejects traversal or uppercase', () => {
  assert.equal(validateSkillName('us-refinement'), true);
  assert.equal(validateSkillName('a1'), true);
  assert.equal(validateSkillName('../x'), false);
  assert.equal(validateSkillName('Upper'), false);
  assert.equal(validateSkillName('-lead'), false);
  assert.equal(validateSkillName(''), false);
});

test('buildAgentPaths lists manifest targets without kiro and adds .claude-* accounts', () => {
  const home = tmp();
  fs.mkdirSync(path.join(home, '.claude-work'));
  fs.writeFileSync(path.join(home, '.claude-file'), 'not a dir');
  const paths = buildAgentPaths('demo', home);
  assert.deepEqual(paths, [
    path.join(home, '.gemini/skills/demo'),
    path.join(home, '.claude/skills/demo'),
    path.join(home, '.config/opencode/skills/demo'),
    path.join(home, '.copilot/skills/demo'),
    path.join(home, '.agents/skills/demo'),
    path.join(home, '.cursor/skills/demo'),
    path.join(home, '.claude-work/skills/demo'),
  ]);
});

test('copySkill copies SKILL.md and known payload dirs only', () => {
  const root = tmp();
  const src = makeSkill(root, 'demo', { extraDirs: ['scripts', 'references', 'unknown'] });
  const target = path.join(root, 'out', 'demo');
  copySkill(target, src, () => {});
  assert.ok(fs.existsSync(path.join(target, 'SKILL.md')));
  assert.ok(fs.existsSync(path.join(target, 'scripts', 'f.txt')));
  assert.ok(fs.existsSync(path.join(target, 'references', 'f.txt')));
  assert.equal(fs.existsSync(path.join(target, 'unknown')), false);
  assert.equal(fs.existsSync(`${target}.staging`), false);
});

test('copySkill replaces an existing install and leaves it intact when the source is invalid', () => {
  const root = tmp();
  const src = makeSkill(root, 'demo');
  const target = path.join(root, 'out', 'demo');
  fs.mkdirSync(target, { recursive: true });
  fs.writeFileSync(path.join(target, 'stale.txt'), 'old');
  copySkill(target, src, () => {});
  assert.equal(fs.existsSync(path.join(target, 'stale.txt')), false);

  const bad = path.join(root, 'bad');
  fs.mkdirSync(bad);
  assert.throws(() => copySkill(target, bad, () => {}), /SKILL\.md not found/);
  assert.ok(fs.existsSync(path.join(target, 'SKILL.md')));
  assert.equal(fs.existsSync(`${target}.staging`), false);
});

test('writeKiroSteering injects inclusion: always after the opening delimiter (LF)', () => {
  const root = tmp();
  const home = tmp();
  const src = makeSkill(root, 'demo');
  const out = writeKiroSteering(src, 'demo', home, () => {});
  assert.equal(out, path.join(home, '.kiro/steering/demo.md'));
  assert.equal(fs.readFileSync(out, 'utf8'), '---\ninclusion: always\nname: demo\n---\nbody\n');
  assert.equal(fs.existsSync(`${out}.staging`), false);
});

test('writeKiroSteering preserves CRLF line endings', () => {
  const root = tmp();
  const home = tmp();
  const src = makeSkill(root, 'demo', { crlf: true });
  const out = writeKiroSteering(src, 'demo', home, () => {});
  assert.equal(
    fs.readFileSync(out, 'utf8'),
    '---\r\ninclusion: always\r\nname: demo\r\n---\r\nbody\r\n',
  );
});

test('writeKiroSteering rejects a SKILL.md without frontmatter', () => {
  const root = tmp();
  const home = tmp();
  const dir = path.join(root, 'demo');
  fs.mkdirSync(dir);
  fs.writeFileSync(path.join(dir, 'SKILL.md'), 'no frontmatter\n');
  assert.throws(() => writeKiroSteering(dir, 'demo', home, () => {}), /YAML frontmatter/);
  assert.equal(fs.existsSync(path.join(home, '.kiro/steering/demo.md')), false);
});
