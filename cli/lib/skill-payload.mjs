// Shared payload helpers for install.mjs: agent path discovery, staged copy/swap,
// and the Kiro steering-file transform. Mirrors cli/lib/skill-payload.sh.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const LIB_DIR = path.dirname(fileURLToPath(import.meta.url));
export const AGENT_TARGETS_MANIFEST = path.join(LIB_DIR, '..', 'agent-targets.json');

const PAYLOAD_DIRS = ['scripts', 'tests', 'assets', 'references', 'examples'];

export function validateSkillName(name) {
  return /^[a-z0-9][a-z0-9-]*$/.test(name);
}

// Static targets from agent-targets.json (entries with a "transform" are handled by
// their own writer) plus every ~/.claude-* account directory found at runtime.
export function buildAgentPaths(skill, home = os.homedir(), manifestPath = AGENT_TARGETS_MANIFEST) {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`agent-targets.json manifest not found at ${manifestPath}`);
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const paths = manifest.targets
    .filter((entry) => !entry.transform)
    .map((entry) => path.join(home, entry.path_template.replace('{skill_name}', skill)));

  const accounts = fs
    .readdirSync(home)
    .filter((name) => name.startsWith('.claude-'))
    .sort()
    .filter((name) => isDirectory(path.join(home, name)));
  for (const name of accounts) {
    paths.push(path.join(home, name, 'skills', skill));
  }
  return paths;
}

export function kiroSteeringPath(skill, home = os.homedir()) {
  return path.join(home, '.kiro', 'steering', `${skill}.md`);
}

function isDirectory(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

// Stages the payload in a sibling ".staging" dir and swaps it into place only after
// every copy succeeds, so a failed copy never corrupts an existing install.
export function copySkill(target, source, log = console.log) {
  const staging = `${target}.staging`;
  const skillFile = path.join(source, 'SKILL.md');
  if (!fs.existsSync(skillFile)) {
    throw new Error(`SKILL.md not found at ${source}`);
  }

  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.rmSync(staging, { recursive: true, force: true });
  fs.mkdirSync(staging, { recursive: true });
  try {
    log(`Copying SKILL.md to: ${target}`);
    fs.copyFileSync(skillFile, path.join(staging, 'SKILL.md'));
    for (const dir of PAYLOAD_DIRS) {
      const from = path.join(source, dir);
      if (isDirectory(from)) {
        log(`Copying ${dir}/ to: ${target}`);
        fs.cpSync(from, path.join(staging, dir), { recursive: true });
      }
    }
    fs.rmSync(target, { recursive: true, force: true });
    fs.renameSync(staging, target);
  } catch (error) {
    fs.rmSync(staging, { recursive: true, force: true });
    throw error;
  }
}

// Kiro reads one flat steering file with `inclusion: always` as the first frontmatter
// key. The injected line copies the source's own EOL style and every other byte passes
// through untouched.
export function writeKiroSteering(source, skill, home = os.homedir(), log = console.log) {
  const target = kiroSteeringPath(skill, home);
  const staging = `${target}.staging`;
  const skillFile = path.join(source, 'SKILL.md');
  if (!fs.existsSync(skillFile)) {
    throw new Error(`SKILL.md not found at ${source}`);
  }

  const content = fs.readFileSync(skillFile);
  const firstNewline = content.indexOf(0x0a);
  const firstLine = (firstNewline === -1 ? content : content.subarray(0, firstNewline))
    .toString('latin1')
    .replace(/\r$/, '');
  if (firstNewline === -1 || firstLine !== '---') {
    throw new Error(
      `SKILL.md at ${source} does not start with a '---' YAML frontmatter delimiter - cannot generate Kiro steering file.`,
    );
  }

  const crlf = content[firstNewline - 1] === 0x0d;
  const injected = Buffer.from(`inclusion: always${crlf ? '\r\n' : '\n'}`);
  const output = Buffer.concat([
    content.subarray(0, firstNewline + 1),
    injected,
    content.subarray(firstNewline + 1),
  ]);

  fs.mkdirSync(path.dirname(target), { recursive: true });
  log(`Generating Kiro steering file: ${target}`);
  fs.writeFileSync(staging, output);
  fs.rmSync(target, { force: true });
  fs.renameSync(staging, target);
  return target;
}
