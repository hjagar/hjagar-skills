import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { run } from '../install.mjs';
import { makeZip } from './helpers/zip.mjs';
import { extractZip, extractSkillNames, selectHighestTag } from '../lib/release.mjs';

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'hjagar-release-'));
}

test('selectHighestTag orders semver numerically per skill', () => {
  const tags = 'alpha-v1.9.0\nalpha-v1.10.0\nalpha-v1.2.0\nbeta-v9.0.0\nalpha-vnext';
  assert.equal(selectHighestTag('alpha', tags.split('\n')), 'alpha-v1.10.0');
  assert.equal(selectHighestTag('gamma', tags.split('\n')), '');
});

test('extractSkillNames returns distinct sorted skill names from versioned tags', () => {
  const tags = ['beta-v1.0.0', 'alpha-v2.0.0', 'alpha-v1.0.0', 'v3.0.0', 'junk'];
  assert.deepEqual(extractSkillNames(tags), ['alpha', 'beta']);
});

test('extractZip writes stored and deflated entries and creates directories', () => {
  const dest = tmp();
  const zip = makeZip([
    { name: 'skills/alpha/', data: '' },
    { name: 'skills/alpha/SKILL.md', data: 'stored body' },
    { name: 'skills/alpha/references/r.md', data: 'deflated '.repeat(50), deflate: true },
  ]);
  extractZip(zip, dest);
  assert.equal(fs.readFileSync(path.join(dest, 'skills/alpha/SKILL.md'), 'utf8'), 'stored body');
  assert.equal(
    fs.readFileSync(path.join(dest, 'skills/alpha/references/r.md'), 'utf8'),
    'deflated '.repeat(50),
  );
});

test('extractZip rejects entries that escape the destination', () => {
  const dest = tmp();
  const zip = makeZip([{ name: '../evil.txt', data: 'x' }]);
  assert.throws(() => extractZip(zip, path.join(dest, 'out')), /unsafe path/);
  assert.equal(fs.existsSync(path.join(dest, 'evil.txt')), false);
});

test('extractZip rejects data that is not a zip', () => {
  assert.throws(() => extractZip(Buffer.from('not a zip at all'), tmp()), /not a valid zip/);
});

function globalHarness(tags, zips) {
  const lines = [];
  const downloads = [];
  return {
    lines,
    downloads,
    io: {
      out: (line) => lines.push(line),
      err: (line) => lines.push(`ERR: ${line}`),
      isInteractive: false,
      confirm: async () => true,
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

function skillZip(name) {
  return makeZip([
    { name: `skills/${name}/SKILL.md`, data: `---\nname: ${name}\n---\nbody\n` },
    { name: `skills/${name}/references/r.md`, data: 'ref' },
    { name: 'cli/lib/skill-payload.sh', data: '#!/bin/sh' },
  ]);
}

test('global install --skill resolves the highest tag, downloads, and installs from the central store', async () => {
  const home = tmp();
  const h = globalHarness(['alpha-v1.0.0', 'alpha-v1.1.0'], { 'alpha-v1.1.0': skillZip('alpha') });
  const code = await run(['install', '--skill', 'alpha', '--yes'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.deepEqual(h.downloads, ['alpha-v1.1.0']);
  assert.ok(fs.existsSync(path.join(home, '.hjagar/skills/skills/alpha/SKILL.md')));
  assert.ok(fs.existsSync(path.join(home, '.claude/skills/alpha/references/r.md')));
  assert.match(h.text(), /Resolved release: alpha-v1\.1\.0/);
});

test('global install without --skill installs every released skill and keeps earlier ones in the central store', async () => {
  const home = tmp();
  const h = globalHarness(['alpha-v1.0.0', 'beta-v2.0.0'], {
    'alpha-v1.0.0': skillZip('alpha'),
    'beta-v2.0.0': skillZip('beta'),
  });
  const code = await run(['install', '--yes'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.match(h.text(), /Discovered skills: alpha beta/);
  for (const skill of ['alpha', 'beta']) {
    assert.ok(fs.existsSync(path.join(home, `.hjagar/skills/skills/${skill}/SKILL.md`)));
    assert.ok(fs.existsSync(path.join(home, `.claude/skills/${skill}/SKILL.md`)));
  }
});

test('global install --dry-run lists the plan and downloads nothing', async () => {
  const home = tmp();
  const h = globalHarness(['alpha-v1.0.0'], {});
  const code = await run(['install', '--skill', 'alpha', '--dry-run'], { home, ...h.io });
  assert.equal(code, 0, h.text());
  assert.match(h.text(), /Dry run/);
  assert.deepEqual(h.downloads, []);
  assert.deepEqual(fs.readdirSync(home), []);
});

test('global install fails clearly when the skill has no release', async () => {
  const home = tmp();
  const h = globalHarness(['beta-v1.0.0'], {});
  const code = await run(['install', '--skill', 'alpha', '--yes'], { home, ...h.io });
  assert.equal(code, 1);
  assert.match(h.text(), /no released version found for skill 'alpha'/);
  assert.deepEqual(fs.readdirSync(home), []);
});
