import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { run } from '../install.mjs';
import { makeZip } from './helpers/zip.mjs';

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'hjagar-upd-'));
}

function skillMd(name, version) {
  return `---\nname: ${name}\nmetadata:\n  version: "${version}"\n---\nbody ${version}\n`;
}

function skillZip(name, version) {
  return makeZip([{ name: `skills/${name}/SKILL.md`, data: skillMd(name, version) }]);
}

// Lays out a previous install: central copy + agent dirs (claude, gemini) + Kiro file.
function seedInstall(home, name, version, { agents = ['.claude', '.gemini'], kiro = true } = {}) {
  const central = path.join(home, '.hjagar/skills/skills', name);
  fs.mkdirSync(central, { recursive: true });
  fs.writeFileSync(path.join(central, 'SKILL.md'), skillMd(name, version));
  for (const agent of agents) {
    const dir = path.join(home, agent, 'skills', name);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'SKILL.md'), skillMd(name, version));
  }
  if (kiro) {
    fs.mkdirSync(path.join(home, '.kiro/steering'), { recursive: true });
    fs.writeFileSync(path.join(home, `.kiro/steering/${name}.md`), 'old steering');
  }
}

function harness({ tags = [], zips = {}, answer = true, interactive = true } = {}) {
  const lines = [];
  const downloads = [];
  const prompts = [];
  return {
    lines,
    downloads,
    prompts,
    io: {
      out: (line) => lines.push(line),
      err: (line) => lines.push(`ERR: ${line}`),
      isInteractive: interactive,
      confirm: async (q) => {
        prompts.push(q);
        return answer;
      },
      releases: {
        fetchTags: async () => tags,
        downloadZip: async (tag) => {
          downloads.push(tag);
          return zips[tag];
        },
      },
    },
    text: () => lines.join('\n'),
  };
}

const read = (home, rel) => fs.readFileSync(path.join(home, rel), 'utf8');

test('update refreshes the central copy and only the agent paths that already exist', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  const h = harness({ tags: ['alpha-v1.0.0', 'alpha-v1.1.0'], zips: { 'alpha-v1.1.0': skillZip('alpha', '1.1.0') } });
  const code = await run(['update', '--skill', 'alpha', '--yes'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.deepEqual(h.downloads, ['alpha-v1.1.0']);
  assert.match(read(home, '.hjagar/skills/skills/alpha/SKILL.md'), /1\.1\.0/);
  assert.match(read(home, '.claude/skills/alpha/SKILL.md'), /1\.1\.0/);
  assert.match(read(home, '.gemini/skills/alpha/SKILL.md'), /1\.1\.0/);
  assert.match(read(home, '.kiro/steering/alpha.md'), /inclusion: always/);
  assert.equal(fs.existsSync(path.join(home, '.cursor')), false);
  assert.match(h.text(), /Update completed successfully to version v1\.1\.0!/);
});

test('update is a no-op when already on the latest version', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.1.0');
  const h = harness({ tags: ['alpha-v1.1.0'] });
  const code = await run(['update', '--skill', 'alpha', '--yes'], { home, ...h.io });
  assert.equal(code, 0);
  assert.deepEqual(h.downloads, []);
  assert.match(h.text(), /already on the latest version/);
});

test('update without --skill checks every locally installed skill', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  seedInstall(home, 'beta', '2.0.0');
  const h = harness({
    tags: ['alpha-v1.1.0', 'beta-v2.0.0'],
    zips: { 'alpha-v1.1.0': skillZip('alpha', '1.1.0') },
  });
  const code = await run(['update', '--yes'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.deepEqual(h.downloads, ['alpha-v1.1.0']);
  assert.match(read(home, '.claude/skills/alpha/SKILL.md'), /1\.1\.0/);
  assert.match(read(home, '.claude/skills/beta/SKILL.md'), /2\.0\.0/);
});

test('update --dry-run prints the plan and changes nothing', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  const h = harness({ tags: ['alpha-v1.1.0'], zips: { 'alpha-v1.1.0': skillZip('alpha', '1.1.0') } });
  const code = await run(['update', '--skill', 'alpha', '--dry-run'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.match(h.text(), /Dry run/);
  assert.match(h.text(), /\.claude[\\/]skills[\\/]alpha/);
  assert.deepEqual(h.downloads, []);
  assert.match(read(home, '.claude/skills/alpha/SKILL.md'), /1\.0\.0/);
});

test('update asks for confirmation and keeps everything when declined', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  const h = harness({ tags: ['alpha-v1.1.0'], answer: false });
  const code = await run(['update', '--skill', 'alpha'], { home, ...h.io });
  assert.equal(code, 0);
  assert.equal(h.prompts.length, 1);
  assert.deepEqual(h.downloads, []);
  assert.match(read(home, '.claude/skills/alpha/SKILL.md'), /1\.0\.0/);
});

test('update fails when nothing is installed or the skill has no release', async () => {
  let home = tmp();
  let h = harness();
  assert.equal(await run(['update', '--yes'], { home, ...h.io }), 1);
  assert.match(h.text(), /skills are not installed globally/);

  home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  h = harness({ tags: ['beta-v1.0.0'] });
  assert.equal(await run(['update', '--skill', 'alpha', '--yes'], { home, ...h.io }), 1);
  assert.match(h.text(), /no released version found for skill 'alpha'/);
});

test('uninstall --skill removes agent dirs, Kiro file and central copy of that skill only', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  seedInstall(home, 'beta', '1.0.0');
  const h = harness();
  const code = await run(['uninstall', '--skill', 'alpha', '--yes'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.equal(fs.existsSync(path.join(home, '.claude/skills/alpha')), false);
  assert.equal(fs.existsSync(path.join(home, '.gemini/skills/alpha')), false);
  assert.equal(fs.existsSync(path.join(home, '.kiro/steering/alpha.md')), false);
  assert.equal(fs.existsSync(path.join(home, '.hjagar/skills/skills/alpha')), false);
  assert.ok(fs.existsSync(path.join(home, '.claude/skills/beta/SKILL.md')));
  assert.ok(fs.existsSync(path.join(home, '.hjagar/skills/skills/beta/SKILL.md')));
  assert.match(h.text(), /Uninstallation completed successfully\./);
});

test('uninstall --all removes every centrally installed skill and the central store', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  seedInstall(home, 'beta', '1.0.0');
  const h = harness();
  const code = await run(['uninstall', '--all', '--yes'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  for (const skill of ['alpha', 'beta']) {
    assert.equal(fs.existsSync(path.join(home, `.claude/skills/${skill}`)), false);
    assert.equal(fs.existsSync(path.join(home, `.kiro/steering/${skill}.md`)), false);
  }
  assert.equal(fs.existsSync(path.join(home, '.hjagar/skills')), false);
});

test('uninstall --dry-run lists only what exists and removes nothing', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0', { agents: ['.claude'], kiro: false });
  const h = harness();
  const code = await run(['uninstall', '--skill', 'alpha', '--dry-run'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.match(h.text(), /\[remove\].*\.claude[\\/]skills[\\/]alpha/);
  assert.doesNotMatch(h.text(), /\.gemini/);
  assert.match(h.text(), /Dry run/);
  assert.ok(fs.existsSync(path.join(home, '.claude/skills/alpha/SKILL.md')));
});

test('uninstall requires --skill or --all, validates the name and reports nothing to remove', async () => {
  const home = tmp();
  let h = harness();
  assert.equal(await run(['uninstall', '--yes'], { home, ...h.io }), 1);
  assert.match(h.text(), /--skill <name> or --all/);

  h = harness();
  assert.equal(await run(['uninstall', '--skill', '../x', '--yes'], { home, ...h.io }), 1);
  assert.match(h.text(), /invalid skill name/);

  h = harness();
  assert.equal(await run(['uninstall', '--skill', 'ghost', '--yes'], { home, ...h.io }), 0);
  assert.match(h.text(), /Nothing to uninstall/);
});

test('uninstall asks for confirmation and removes nothing when declined', async () => {
  const home = tmp();
  seedInstall(home, 'alpha', '1.0.0');
  const h = harness({ answer: false });
  assert.equal(await run(['uninstall', '--skill', 'alpha'], { home, ...h.io }), 0);
  assert.equal(h.prompts.length, 1);
  assert.ok(fs.existsSync(path.join(home, '.claude/skills/alpha/SKILL.md')));
});
