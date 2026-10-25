// Release helpers for install.mjs: tag selection, GitHub access and a dependency-free
// zip reader (Node has no built-in unzip). Mirrors the release logic in cli/install.sh.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';

export const REPO = 'hjagar/hjagar-skills';

const VERSION_TAG = /^([a-z0-9][a-z0-9-]*)-v(\d+)\.(\d+)\.(\d+)$/;

// Highest `<skill>-vX.Y.Z` tag with numeric ordering (v1.10.0 > v1.9.0), or '' if none.
export function selectHighestTag(skill, tags) {
  const matches = tags
    .map((tag) => VERSION_TAG.exec(tag))
    .filter((m) => m && m[1] === skill)
    .sort((a, b) => a.slice(2).map(Number).reduce((diff, n, i) => diff || n - Number(b[i + 2]), 0));
  return matches.length ? matches[matches.length - 1][0] : '';
}

export function extractSkillNames(tags) {
  const names = tags.map((tag) => VERSION_TAG.exec(tag)).filter(Boolean).map((m) => m[1]);
  return [...new Set(names)].sort();
}

function gh(args) {
  return execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
}

export async function fetchTags(repo = REPO) {
  try {
    const raw = gh(['api', '--paginate', `repos/${repo}/releases`, '--jq', '.[].tag_name']);
    const tags = raw.split(/\r?\n/).filter(Boolean);
    if (tags.length) return tags;
  } catch {
    // gh missing or unauthenticated: fall back to the public API.
  }
  const tags = [];
  for (let page = 1; ; page++) {
    const res = await fetch(`https://api.github.com/repos/${repo}/releases?per_page=100&page=${page}`);
    if (!res.ok) throw new Error(`GitHub API responded ${res.status} while listing releases for ${repo}`);
    const batch = await res.json();
    if (batch.length === 0) break;
    tags.push(...batch.map((release) => release.tag_name));
  }
  return tags;
}

export async function downloadZip(tag, skill, repo = REPO) {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'hjagar-dl-'));
  try {
    const out = path.join(scratch, `${skill}.zip`);
    try {
      gh(['release', 'download', tag, '--repo', repo, '--pattern', `${skill}.zip`, '--output', out, '--clobber']);
      return fs.readFileSync(out);
    } catch {
      // fall back to the public download URL
    }
    const res = await fetch(`https://github.com/${repo}/releases/download/${tag}/${skill}.zip`);
    if (!res.ok) throw new Error(`download of ${tag} failed with status ${res.status}`);
    return Buffer.from(await res.arrayBuffer());
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

const EOCD_SIG = 0x06054b50;
const CENTRAL_SIG = 0x02014b50;
const LOCAL_SIG = 0x04034b50;

// Extracts a zip held in memory into destDir. Supports stored and deflated entries
// (what `zip`/`Compress-Archive` produce); rejects zip64 and any entry that would land
// outside destDir.
export function extractZip(buffer, destDir) {
  let eocd = -1;
  for (let i = buffer.length - 22; i >= Math.max(0, buffer.length - 22 - 0xffff); i--) {
    if (buffer.readUInt32LE(i) === EOCD_SIG) {
      eocd = i;
      break;
    }
  }
  if (eocd === -1) throw new Error('not a valid zip archive');

  const count = buffer.readUInt16LE(eocd + 10);
  let cursor = buffer.readUInt32LE(eocd + 16);
  if (count === 0xffff || cursor === 0xffffffff) throw new Error('zip64 archives are not supported');

  const root = path.resolve(destDir);
  for (let n = 0; n < count; n++) {
    if (buffer.readUInt32LE(cursor) !== CENTRAL_SIG) throw new Error('not a valid zip archive');
    const method = buffer.readUInt16LE(cursor + 10);
    const compressedSize = buffer.readUInt32LE(cursor + 20);
    const nameLength = buffer.readUInt16LE(cursor + 28);
    const extraLength = buffer.readUInt16LE(cursor + 30);
    const commentLength = buffer.readUInt16LE(cursor + 32);
    const mode = buffer.readUInt32LE(cursor + 38) >>> 16;
    const localOffset = buffer.readUInt32LE(cursor + 42);
    const name = buffer.toString('utf8', cursor + 46, cursor + 46 + nameLength).replaceAll('\\', '/');
    cursor += 46 + nameLength + extraLength + commentLength;

    const target = path.resolve(root, name);
    if (target !== root && !target.startsWith(root + path.sep)) {
      throw new Error(`zip entry has an unsafe path: ${name}`);
    }
    if (name.endsWith('/')) {
      fs.mkdirSync(target, { recursive: true });
      continue;
    }

    if (buffer.readUInt32LE(localOffset) !== LOCAL_SIG) throw new Error('not a valid zip archive');
    const dataStart = localOffset + 30 + buffer.readUInt16LE(localOffset + 26) + buffer.readUInt16LE(localOffset + 28);
    const body = buffer.subarray(dataStart, dataStart + compressedSize);
    let data;
    if (method === 0) data = body;
    else if (method === 8) data = zlib.inflateRawSync(body);
    else throw new Error(`unsupported zip compression method ${method} for ${name}`);

    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, data);
    if (mode & 0o111) fs.chmodSync(target, mode & 0o777);
  }
}
