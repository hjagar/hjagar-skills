#!/usr/bin/env node
// hjagar-skills installer: `install`, `update` and `uninstall` subcommands.
// Node port of cli/install.sh, update.sh and uninstall.sh (no external dependencies).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import {
  buildAgentPaths,
  copySkill,
  kiroSteeringPath,
  validateSkillName,
  writeKiroSteering,
} from './lib/skill-payload.mjs';
import { REPO, downloadZip, extractSkillNames, extractZip, fetchTags, selectHighestTag } from './lib/release.mjs';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

const USAGE = `Usage: install.mjs <install|update|uninstall> [options]

Options:
  -l, --local         install from a local checkout (install only)
  -p, --path <dir>    checkout to install from (with --local)
  --skill <name>      act on a single skill
  --dry-run           print the plan and change nothing
  -y, --yes           skip the confirmation prompt
  -h, --help          show this help`;

class UsageError extends Error {}

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const options = { command, local: false, srcDir: '', skill: '', dryRun: false, yes: false, help: false };
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    switch (arg) {
      case '-l':
      case '--local':
        options.local = true;
        break;
      case '-p':
      case '--path':
        options.srcDir = rest[++i] ?? '';
        break;
      case '--skill':
        options.skill = rest[++i] ?? '';
        break;
      case '--dry-run':
        options.dryRun = true;
        break;
      case '-y':
      case '--yes':
        options.yes = true;
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
      default:
        throw new UsageError(`Unknown parameter: ${arg}`);
    }
  }
  return options;
}

// Same resolution rules as install.sh `install_skills`: a skills/<name>/ layout first,
// then a flat payload (SKILL.md at the base) installed under the requested name.
function resolveLocalSkills(baseDir, requested) {
  const skillsDir = path.join(baseDir, 'skills');
  const hasFile = (p) => fs.existsSync(p) && fs.statSync(p).isFile();
  const skills = [];

  if (requested) {
    if (hasFile(path.join(skillsDir, requested, 'SKILL.md'))) {
      skills.push({ name: requested, dir: path.join(skillsDir, requested) });
    } else if (hasFile(path.join(baseDir, 'SKILL.md'))) {
      skills.push({ name: requested, dir: baseDir });
    } else {
      throw new Error(`Skill '${requested}' not found in ${baseDir}`);
    }
  } else if (fs.existsSync(skillsDir)) {
    for (const entry of fs.readdirSync(skillsDir).sort()) {
      const dir = path.join(skillsDir, entry);
      if (hasFile(path.join(dir, 'SKILL.md'))) skills.push({ name: entry, dir });
    }
  } else if (hasFile(path.join(baseDir, 'SKILL.md'))) {
    skills.push({ name: path.basename(baseDir), dir: baseDir });
  }

  if (skills.length === 0) throw new Error('No valid skills found to install.');
  return skills;
}

function planInstall(skills, home) {
  const entries = [];
  for (const skill of skills) {
    const targets = [...buildAgentPaths(skill.name, home), kiroSteeringPath(skill.name, home)];
    for (const target of targets) {
      entries.push({ skill: skill.name, target, action: fs.existsSync(target) ? 'replace' : 'create' });
    }
  }
  return entries;
}

function printPlan(entries, io) {
  io.out('Plan:');
  for (const entry of entries) {
    io.out(`  [${entry.action}] ${entry.skill}: ${entry.target}`);
  }
}

// Shows the plan, then either stops (--dry-run), proceeds (--yes) or asks. Returns an
// exit code when the command must end here, or null to carry on with the changes.
async function gate(entries, options, io) {
  printPlan(entries, io);
  if (options.dryRun) {
    io.out('Dry run: no changes were made.');
    return 0;
  }
  if (options.yes) return null;
  if (!io.isInteractive) {
    io.err('Refusing to change anything without confirmation in a non-interactive session. Re-run with --yes.');
    return 1;
  }
  if (!(await io.confirm('Proceed? (y/N) '))) {
    io.out('Cancelled.');
    return 0;
  }
  return null;
}

function installFromSource(skill, io) {
  io.out(`Installing skill '${skill.name}'...`);
  for (const agent of buildAgentPaths(skill.name, io.home)) {
    copySkill(agent, skill.dir, io.out);
  }
  writeKiroSteering(skill.dir, skill.name, io.home, io.out);
}

async function installLocal(options, io) {
  const baseDir = options.srcDir
    ? path.resolve(options.srcDir)
    : fs.existsSync(path.join(SCRIPT_DIR, '..', 'skills'))
      ? path.resolve(SCRIPT_DIR, '..')
      : SCRIPT_DIR;

  io.out('Installing in LOCAL Mode...');
  const skills = resolveLocalSkills(baseDir, options.skill);
  const exit = await gate(planInstall(skills, io.home), options, io);
  if (exit !== null) return exit;

  for (const skill of skills) installFromSource(skill, io);
  io.out('Installation completed successfully!');
  return 0;
}

function centralDir(home) {
  return path.join(home, '.hjagar', 'skills');
}

// Unpacks one skill's release zip into the central store (~/.hjagar/skills/skills/<name>),
// replacing only that skill so earlier installs survive. Extracted in a scratch dir first
// so a bad archive never leaves a half-written central copy.
function unpackToCentral(zip, skill, home) {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'hjagar-extract-'));
  try {
    extractZip(zip, scratch);
    const nested = path.join(scratch, 'skills', skill);
    const source = fs.existsSync(path.join(nested, 'SKILL.md')) ? nested : scratch;
    if (!fs.existsSync(path.join(source, 'SKILL.md'))) {
      throw new Error(`release archive for '${skill}' does not contain a SKILL.md`);
    }
    const dest = path.join(centralDir(home), 'skills', skill);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.rmSync(dest, { recursive: true, force: true });
    fs.cpSync(source, dest, { recursive: true });
    return dest;
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

async function installGlobal(options, io) {
  io.out('Installing in GLOBAL Mode...');
  let tags;
  try {
    tags = await io.releases.fetchTags();
  } catch (error) {
    throw new Error(`Failed to query releases for ${REPO}: ${error.message}`);
  }

  let names;
  if (options.skill) {
    names = [options.skill];
  } else {
    io.out(`No --skill specified; discovering all released skills in ${REPO}...`);
    names = extractSkillNames(tags);
    if (names.length === 0) throw new Error(`no releases found in ${REPO}.`);
    io.out(`Discovered skills: ${names.join(' ')}`);
  }

  const releases = names.map((name) => ({ name, tag: selectHighestTag(name, tags) }));
  for (const { name, tag } of releases) {
    if (!tag) {
      throw new Error(
        `no released version found for skill '${name}' in ${REPO}.
` +
          'Install from a local checkout instead: install.mjs install --local -p <path>',
      );
    }
    io.out(`Resolved release: ${tag}`);
  }

  const entries = planInstall(releases, io.home);
  for (const { name } of releases) {
    const target = path.join(centralDir(io.home), 'skills', name);
    entries.push({ skill: name, target, action: fs.existsSync(target) ? 'replace' : 'create' });
  }
  const exit = await gate(entries, options, io);
  if (exit !== null) return exit;

  for (const { name, tag } of releases) {
    io.out(`Downloading release ZIP for ${tag}...`);
    const zip = await io.releases.downloadZip(tag, name);
    const dir = unpackToCentral(zip, name, io.home);
    installFromSource({ name, dir }, io);
  }
  io.out('Installation completed successfully!');
  return 0;
}

async function install(options, io) {
  return options.local ? installLocal(options, io) : installGlobal(options, io);
}

export async function run(argv, overrides = {}) {
  const io = {
    home: os.homedir(),
    out: (line) => console.log(line),
    err: (line) => console.error(line),
    isInteractive: Boolean(process.stdin.isTTY),
    releases: { fetchTags: () => fetchTags(), downloadZip: (tag, skill) => downloadZip(tag, skill) },
    confirm: async (question) => {
      const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
      try {
        return /^y(es)?$/i.test((await rl.question(question)).trim());
      } finally {
        rl.close();
      }
    },
    ...overrides,
  };

  try {
    if (argv.length === 0 || argv[0] === '-h' || argv[0] === '--help') {
      io.out(USAGE);
      return argv.length === 0 ? 1 : 0;
    }
    const options = parseArgs(argv);
    if (options.help) {
      io.out(USAGE);
      return 0;
    }
    if (options.skill && !validateSkillName(options.skill)) {
      throw new Error(`invalid skill name '${options.skill}'.`);
    }
    switch (options.command) {
      case 'install':
        return await install(options, io);
      default:
        throw new UsageError(`Unknown command: ${options.command}`);
    }
  } catch (error) {
    io.err(error instanceof UsageError ? `${error.message}\n${USAGE}` : `Error: ${error.message}`);
    return 1;
  }
}

const invokedDirectly =
  process.argv[1] && pathToFileURL(fs.realpathSync(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  process.exitCode = await run(process.argv.slice(2));
}
