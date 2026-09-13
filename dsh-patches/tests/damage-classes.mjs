// Regression suite for the patched repair module. Builds fixtures from a real
// stored session log (newest v3 generation in the store) so every row shape and
// every citation is authentic, then fabricates the damage classes the tool
// claims to heal and verifies the result through dsh's own persistence service.
//
// Run:
//   ELECTRON_RUN_AS_NODE=1 DSH_CHECKOUT="$DSH_ASAR/node_modules" \
//     "$DSH_ASAR/../MacOS/DSH Desktop" tests/damage-classes.mjs
import { mkdirSync, rmSync, writeFileSync, readFileSync, readdirSync, openSync, closeSync } from 'node:fs'
import { join } from 'node:path'
import { createHash, randomUUID } from 'node:crypto'
import { createRequire } from 'node:module'
import { zstdCompressSync, constants as zstdConstants } from 'node:zlib'
import { homedir } from 'node:os'
import { repairSessionStore, readLogFile, checkLog, checkLogRecoverable, repairEvents } from '../session-repair.mjs'

const ASAR = process.env.DSH_CHECKOUT ?? '/Applications/DSH Desktop.app/Contents/Resources/app.asar/node_modules'
const req = createRequire(join(ASAR, '@deepseek-ai', 'dsh-session', 'noop.js'))
const cordis = req('@deepseek-ai/cordis')
const persistPlugin = req('@deepseek-ai/dsh-session-persistence-jsonl')
const plugin = persistPlugin.default ?? persistPlugin
const { decodeSeqRanges, encodeSeqRanges } = req('@deepseek-ai/dsh-session')

const CHECKSUM_OPTIONS = { params: { [zstdConstants.ZSTD_c_checksumFlag]: 1 } }
const frame = (text) => zstdCompressSync(Buffer.from(text), CHECKSUM_OPTIONS)
const body = (rows) => `${rows.map((r) => JSON.stringify(r)).join('\n')}\n`

/** Newest stored v3 log that carries at least one completed turn. */
function pickFixture() {
  const store = join(homedir(), '.dsh', 'sessions')
  const candidates = []
  for (const ws of readdirSync(store)) {
    for (const id of readdirSync(join(store, ws))) {
      const file = join(store, ws, id, 'session.v3.jsonl.zstd')
      try { candidates.push({ file, mtime: readFileSync(file).length }) } catch { /* not a v3 log */ }
    }
  }
  for (const candidate of candidates.sort((a, b) => b.mtime - a.mtime)) {
    try {
      const parsed = readLogFile(candidate.file)
      if (parsed.rows.some((r) => r.type === 'turn/end')) return parsed
    } catch { /* skip unreadable */ }
  }
  throw new Error('no usable stored v3 session log found')
}

const fixture = pickFixture()
const liveRows = fixture.rows
const firstTurnEnd = liveRows.findIndex((r) => r.type === 'turn/end')
const segment = liveRows.slice(0, firstTurnEnd + 1)
console.log(`fixture: ${fixture.file} — using the first turn (${segment.length} rows)`)

const WS = '--Users-algive-jizhang_01--'
const root = join('/tmp', `dsh-repair-fixtures-${process.pid}`)
rmSync(root, { recursive: true, force: true })
mkdirSync(root, { recursive: true })

const cases = {}
const ids = {}
function writeCase(label, rows) {
  const id = ids[label] = `session-${randomUUID()}`
  const dir = join(root, WS, id)
  mkdirSync(dir, { recursive: true })
  const file = join(dir, 'session.v3.jsonl.zstd')
  writeFileSync(file, Buffer.concat([frame(`${JSON.stringify({ ...fixture.header, id })}\n`), frame(body(rows))]))
  cases[label] = file
  return file
}

/** Drop rows, then renumber seqs and their citations consistently. */
function dropRows(rows, drop) {
  const kept = []
  const oldToNew = new Map()
  rows.forEach((row, index) => {
    if (drop(row)) return
    oldToNew.set(index, kept.length)
    kept.push(row)
  })
  return kept.map((row, index) => {
    const out = { ...row, seq: index }
    if (Array.isArray(row.sourceEventSeqs)) {
      out.sourceEventSeqs = encodeSeqRanges(decodeSeqRanges(row.sourceEventSeqs).map((s) => oldToNew.get(s) ?? s))
    }
    return out
  })
}

writeCase('healthy', segment.map((r, i) => ({ ...r, seq: i })))
writeCase('missingStep', dropRows(segment, (r) => r.type === 'step/start' || r.type === 'step/end'))
writeCase('seam', [...segment, ...segment.slice(10)])
// a complete frame whose final body line was truncated mid-write
{
  const id = `session-${randomUUID()}`
  ids.trailingRow = id
  const dir = join(root, WS, id)
  mkdirSync(dir, { recursive: true })
  const rows = segment.map((r, i) => ({ ...r, seq: i }))
  const file = join(dir, 'session.v3.jsonl.zstd')
  writeFileSync(file, Buffer.concat([
    frame(`${JSON.stringify({ ...fixture.header, id })}\n`),
    frame(`${body(rows)}{"type":"user/message","seq":999,"time":1`),
  ]))
  cases.trailingRow = file
}

const sha = (f) => createHash('sha256').update(readFileSync(f)).digest('hex')
const report = (file) => {
  const parsed = readLogFile(file)
  const strict = checkLog(parsed.header, parsed.rows)
  const lenient = checkLogRecoverable(parsed.header, parsed.rows)
  return `strict=${strict.ok ? `clean(${strict.events})` : strict.error.slice(0, 60)} lenient=${lenient.ok ? `${lenient.events} events` : 'error'}`
}

console.log('=== before repair')
for (const [label, file] of Object.entries(cases)) console.log(`${label.padEnd(13)} ${report(file)}`)
const before = Object.fromEntries(Object.entries(cases).map(([k, f]) => [k, sha(f)]))

// unit: citation hygiene and seam remap must not corrupt citations
{
  const rows = dropRows(segment, (r) => r.type === 'step/start' || r.type === 'step/end')
  const at = rows.findIndex((r) => r.type === 'assistant/message')
  rows[at] = { ...rows[at], sourceEventSeqs: [0, 1] }
  const out = repairEvents(JSON.parse(JSON.stringify(rows)))
  const citations = out.find((r) => r.type === 'assistant/message')?.sourceEventSeqs
  console.log('citation hygiene: [0,1] (not chunks) →', JSON.stringify(citations))
}

console.log('=== repair')
console.log(JSON.stringify(repairSessionStore({ fix: true, root }), null, 2))

console.log('=== after repair')
let failures = 0
for (const [label, file] of Object.entries(cases)) {
  const strict = checkLog(readLogFile(file).header, readLogFile(file).rows)
  const changed = sha(file) !== before[label]
  const expected = label === 'healthy' ? false : true
  const ok = strict.ok && changed === expected
  if (!ok) failures += 1
  console.log(`${label.padEnd(13)} ${report(file)} changed=${changed} ${ok ? 'OK' : 'FAIL'}`)
}

console.log('=== dsh persistence write-open (the path that used to throw)')
for (const [label, id] of Object.entries(ids)) {
  const ctx = new cordis.Context()
  ctx.plugin(plugin, { root, compression: 'zstd' })
  await new Promise((r) => setTimeout(r, 200))
  try {
    const handle = await ctx.get('sessionPersistence').open(id, { access: 'write' })
    const slice = await handle.read(0, 100000)
    await handle.close?.()
    console.log(`${label.padEnd(13)} ok, ${(slice?.events ?? slice).length} events`)
  } catch (error) {
    failures += 1
    console.log(`${label.padEnd(13)} FAILED: ${String(error?.message ?? error).slice(0, 120)}`)
  }
}

console.log('=== in-use skip guard')
{
  const file = writeCase('locked', dropRows(segment, (r) => r.type === 'step/start'))
  const fd = openSync(file, 'r')
  const summary = repairSessionStore({ fix: true, root })
  closeSync(fd)
  const skipped = summary.skipped.some((entry) => entry.includes(ids.locked))
  const untouched = checkLog(readLogFile(file).header, readLogFile(file).rows).ok === false
  console.log(`skipped=${skipped} untouched=${untouched} ${skipped && untouched ? 'OK' : 'FAIL'}`)
  if (!(skipped && untouched)) failures += 1
}

rmSync(root, { recursive: true, force: true })
console.log(failures === 0 ? '\nALL CHECKS PASSED' : `\n${failures} CHECK(S) FAILED`)
process.exitCode = failures === 0 ? 0 : 1
