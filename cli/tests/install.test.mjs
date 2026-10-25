import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { run } from '../install.mjs';

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'hjagar-install-'));
}

function makeRepo(skills = ['alpha', 'beta']) {
  const root = tmp();
  for (const name of skills) {
    const dir = path.join(root, 'skills', name);
    fs.mkdirSync(path.join(dir, 'references'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'SKILL.md'), `---\nname: ${name}\n---\nbody\n`);
    fs.writeFileSync(path.join(dir, 'references', 'r.md'), 'ref');
  }
  return root;
}

function harness({ answer = true, interactive = true } = {}) {
  const lines = [];
  const prompts = [];
  return {
    lines,
    prompts,
    io: {
      out: (line) => lines.push(line),
      err: (line) => lines.push(`ERR: ${line}`),
      isInteractive: interactive,
      confirm: async (question) => {
        prompts.push(question);
        return answer;
      },
    },
    text: () => lines.join('\n'),
  };
}

test('install --dry-run prints the plan and changes nothing', async () => {
  const repo = makeRepo();
  const home = tmp();
  const h = harness();
  const code = await run(['install', '-l', '-p', repo, '--dry-run'], { home, ...h.io });
  assert.equal(code, 0);
  assert.match(h.text(), /Dry run/);
  assert.match(h.text(), /alpha/);
  assert.match(h.text(), /\.claude[\\/]skills[\\/]alpha/);
  assert.match(h.text(), /\.kiro[\\/]steering[\\/]alpha\.md/);
  assert.equal(h.prompts.length, 0);
  assert.deepEqual(fs.readdirSync(home), []);
});

test('install --yes installs every skill into each agent dir and Kiro', async () => {
  const repo = makeRepo();
  const home = tmp();
  fs.mkdirSync(path.join(home, '.claude-work'));
  const h = harness();
  const code = await run(['install', '-l', '-p', repo, '--yes'], { home, ...h.io });
  assert.equal(code, 0);
  assert.equal(h.prompts.length, 0);
  for (const skill of ['alpha', 'beta']) {
    for (const rel of [
      `.gemini/skills/${skill}`,
      `.claude/skills/${skill}`,
      `.config/opencode/skills/${skill}`,
      `.copilot/skills/${skill}`,
      `.agents/skills/${skill}`,
      `.cursor/skills/${skill}`,
      `.claude-work/skills/${skill}`,
    ]) {
      assert.ok(fs.existsSync(path.join(home, rel, 'SKILL.md')), rel);
      assert.ok(fs.existsSync(path.join(home, rel, 'references', 'r.md')), rel);
    }
    assert.match(fs.readFileSync(path.join(home, `.kiro/steering/${skill}.md`), 'utf8'), /inclusion: always/);
  }
  assert.match(h.text(), /Installation completed successfully!/);
});

test('install --skill installs only the named skill', async () => {
  const repo = makeRepo();
  const home = tmp();
  const h = harness();
  const code = await run(['install', '-l', '-p', repo, '--skill', 'beta', '-y'], { home, ...h.io });
  assert.equal(code, 0);
  assert.ok(fs.existsSync(path.join(home, '.claude/skills/beta/SKILL.md')));
  assert.equal(fs.existsSync(path.join(home, '.claude/skills/alpha')), false);
});

test('install asks for confirmation and aborts without changes when declined', async () => {
  const repo = makeRepo();
  const home = tmp();
  const h = harness({ answer: false });
  const code = await run(['install', '-l', '-p', repo], { home, ...h.io });
  assert.equal(code, 0);
  assert.equal(h.prompts.length, 1);
  assert.match(h.text(), /Cancelled/);
  assert.deepEqual(fs.readdirSync(home), []);
});

test('install without --yes refuses to run when not interactive', async () => {
  const repo = makeRepo();
  const home = tmp();
  const h = harness({ interactive: false });
  const code = await run(['install', '-l', '-p', repo], { home, ...h.io });
  assert.equal(code, 1);
  assert.match(h.text(), /--yes/);
  assert.deepEqual(fs.readdirSync(home), []);
});

test('plan marks existing installs as replace', async () => {
  const repo = makeRepo(['alpha']);
  const home = tmp();
  fs.mkdirSync(path.join(home, '.claude/skills/alpha'), { recursive: true });
  const h = harness();
  await run(['install', '-l', '-p', repo, '--dry-run'], { home, ...h.io });
  const claudeLine = h.lines.find((l) => /\.claude[\\/]skills[\\/]alpha/.test(l));
  const geminiLine = h.lines.find((l) => /\.gemini[\\/]skills[\\/]alpha/.test(l));
  assert.match(claudeLine, /replace/);
  assert.match(geminiLine, /create/);
});

test('install rejects an invalid skill name, a missing skill and unknown options', async () => {
  const repo = makeRepo();
  const home = tmp();
  let h = harness();
  assert.equal(await run(['install', '-l', '-p', repo, '--skill', '../x', '-y'], { home, ...h.io }), 1);
  assert.match(h.text(), /invalid skill name/);

  h = harness();
  assert.equal(await run(['install', '-l', '-p', repo, '--skill', 'ghost', '-y'], { home, ...h.io }), 1);
  assert.match(h.text(), /Skill 'ghost' not found/);

  h = harness();
  assert.equal(await run(['install', '--bogus'], { home, ...h.io }), 1);
  assert.match(h.text(), /Unknown parameter: --bogus/);

  h = harness();
  assert.equal(await run(['frobnicate'], { home, ...h.io }), 1);
  assert.match(h.text(), /Unknown command: frobnicate/);
  assert.deepEqual(fs.readdirSync(home), []);
});

test('flags that do not apply to the subcommand, or lack a value, are rejected without changes', async () => {
  const repo = makeRepo();
  const home = tmp();
  const cases = [
    [['uninstall', '--skill', 'x', '--local'], /--local/],
    [['update', '--local'], /--local/],
    [['install', '-l', '-p', repo, '--all'], /--all/],
    [['update', '--all'], /--all/],
    [['install', '-p', repo], /--path requires --local/],
    [['install', '-l', '-p'], /Missing value for -p/],
    [['install', '--skill'], /Missing value for --skill/],
  ];
  for (const [argv, pattern] of cases) {
    const h = harness();
    assert.equal(await run([...argv, '--dry-run'], { home, ...h.io }), 1, argv.join(' '));
    assert.match(h.text(), pattern, argv.join(' '));
  }
  assert.deepEqual(fs.readdirSync(home), []);
});
