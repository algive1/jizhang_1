/**
 * Session-log repair for the "token meter: assistant/message at seq N has no
 * matching step/start event" family of cold-replay failures.
 *
 * ── Why this file is patched locally (dsh-codex-sync 1.6.1 → 1.6.1-dsh2.0) ──
 * The 1.6.1 module decoded rows with `decodeStorageRecord` imported from
 * `@deepseek-ai/dsh-session` and validated candidates with a hand-built
 * TokenMeter. DSH Desktop 2.0.x:
 *   * no longer exports `decodeStorageRecord` (the row codec lives in
 *     `dsh-session/chunk-rows` and is not a public subpath), so EVERY row threw
 *     and every scanned legacy log was flagged damaged;
 *   * stores generation logs — `session.jsonl.zstd` (v0, legacy) and
 *     `session.v<N>.jsonl.zstd` (vN, current; the highest generation wins) —
 *     while the old scanner only looked at `session.jsonl.zstd`;
 *   * validates replay through `sessionFormatCatalog` (v0→v1→v2→v3 migration
 *     chain + installed-Session admission) plus the real TokenMeter.
 * Net effect of the old code on this build: a false "damaged" verdict for every
 * legacy log and a hard throw (`session header version must be 3, got 0`) from
 * `--fix`, with nothing ever repaired.
 *
 * ── What this version does ──
 *   1. reads every generation log with a dependency-free multi-frame
 *      Zstandard decoder (scanZstdFrames ported from
 *      `@deepseek-ai/dsh-session-persistence-jsonl`, MIT, same repo family);
 *   2. validates a log exactly like the app does when it opens a session for
 *      write or migrates it on a model switch: catalog restore through the
 *      released format chain with STRICT recovery, installed Session admission,
 *      then the real `@deepseek-ai/dsh-token-meter` fold. Strict recovery is the
 *      point: the lenient reader path hides the same damage by silently dropping
 *      everything after the first bad row;
 *   3. repairs the same three damage classes as before, now on raw rows:
 *      stale-cursor seam, unpaired step markers, invalid chunk citations, plus
 *      seq renumbering and dropping a trailing torn row;
 *   4. never writes an unverified repair — the repaired bytes are re-read and
 *      re-validated, and the file is restored from its backup if they are not
 *      clean. A log held open by a live process is skipped instead of
 *      rewritten, and an existing `.bak` is never overwritten.
 *
 * Known limitations (each one is reported, never written half-repaired):
 *   * a log containing packed chunk rows (`text-chunks`, `reasoning-chunks`,
 *     `tool-call-chunks`) is refused, because renumbering inside a packed run is
 *     not implemented;
 *   * seam repair remaps `sourceEventSeqs` only — a surface operation payload
 *     carrying its own seq references (e.g. a `replace` op) can leave the
 *     repaired log failing strict validation, in which case the original file is
 *     left untouched;
 *   * a container whose final Zstandard frame is unfinished is skipped, since it
 *     is most likely a session being written right now.
 */
import { execFileSync } from 'node:child_process'
import { copyFileSync, existsSync, readFileSync, readdirSync, renameSync, statSync, writeFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { homedir } from 'node:os'
import { zstdCompressSync, zstdDecompressSync, constants as zstdConstants } from 'node:zlib'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)

/**
 * Resolve dsh's own packages. Inside the live profile the plugin sits next to
 * @deepseek-ai/*, so plain require works; a repo/dev checkout needs
 * DSH_CHECKOUT (the dsh install dir) or DSH_HOME to find them.
 */
function dshPackage(name) {
  const attempts = []
  const fromSpec = (spec) => {
    try { return require(spec) } catch { return undefined }
  }
  attempts.push(`@deepseek-ai/${name}`)
  const home = process.env.DSH_HOME ?? join(homedir(), '.dsh')
  for (const base of [process.env.DSH_CHECKOUT, join(home, 'profiles', 'web', 'node_modules'), join(home, 'profiles', 'desktop', 'node_modules')]) {
    if (!base) continue
    const r = createRequire(join(base, '@deepseek-ai', name, 'noop.js'))
    try {
      const mod = r(`@deepseek-ai/${name}`)
      if (mod !== undefined) return mod
    } catch { /* try next base */ }
    void r
  }
  void attempts
  throw new Error(
    `cannot resolve @deepseek-ai/${name}; run inside the dsh profile, `
    + 'or set DSH_CHECKOUT to the deepseek-ai/dsh install directory',
  )
}

//#region zstd container
/** Zstandard frame magic (`0xFD2FB528` little-endian). */
const ZSTD_MAGIC = 4247762216
/** Same frame options dsh's own writer uses: checksummed frames. */
const CHECKSUM_OPTIONS = { params: { [zstdConstants.ZSTD_c_checksumFlag]: 1 } }

/**
 * Locate complete Zstandard frames without decompressing their blocks.
 * Ported verbatim from `@deepseek-ai/dsh-session-persistence-jsonl`'s
 * `scanZstdFrames` so this tool reads the same concatenated-frame container the
 * app writes (header frame + one frame per appended batch).
 * @param buffer - complete bytes currently present in the session artifact.
 * @param maxFrames - optional complete-frame limit for metadata-only readers.
 * @returns complete frame ranges and an optional incomplete-final-frame start.
 */
function scanZstdFrames(buffer, maxFrames = Number.POSITIVE_INFINITY) {
  const frames = []
  let offset = 0
  while (offset < buffer.length) {
    const start = offset
    if (buffer.length - offset < 4) return { frames, tornStart: start }
    if (buffer.readUInt32LE(offset) !== ZSTD_MAGIC) throw new Error(`corrupt Zstandard session log: invalid frame magic at byte ${offset}`)
    offset += 4
    if (offset === buffer.length) return { frames, tornStart: start }
    const descriptor = buffer.readUInt8(offset)
    offset += 1
    if ((descriptor & 24) !== 0) throw new Error(`corrupt Zstandard session log: reserved frame-header bit at byte ${offset - 1}`)
    const contentSizeFlag = descriptor >>> 6
    const singleSegment = (descriptor & 32) !== 0
    const checksum = (descriptor & 4) !== 0
    const dictionaryFlag = descriptor & 3
    const dictionaryBytes = dictionaryFlag === 3 ? 4 : dictionaryFlag
    const contentSizeBytes = contentSizeFlag === 0 ? (singleSegment ? 1 : 0) : 1 << contentSizeFlag
    const remainingHeaderBytes = (singleSegment ? 0 : 1) + dictionaryBytes + contentSizeBytes
    if (buffer.length - offset < remainingHeaderBytes) return { frames, tornStart: start }
    offset += remainingHeaderBytes
    for (;;) {
      if (buffer.length - offset < 3) return { frames, tornStart: start }
      const blockHeader = buffer.readUIntLE(offset, 3)
      offset += 3
      const lastBlock = (blockHeader & 1) !== 0
      const blockType = (blockHeader >>> 1) & 3
      const blockSize = blockHeader >>> 3
      if (blockType === 3) throw new Error(`corrupt Zstandard session log: reserved block type at byte ${offset - 3}`)
      const payloadBytes = blockType === 1 ? 1 : blockSize
      if (buffer.length - offset < payloadBytes) return { frames, tornStart: start }
      offset += payloadBytes
      if (lastBlock) break
    }
    if (checksum) {
      if (buffer.length - offset < 4) return { frames, tornStart: start }
      offset += 4
    }
    frames.push({ start, end: offset })
    if (frames.length === maxFrames) return { frames }
  }
  return { frames }
}

/** Decode the concatenated-frame container into its JSONL plaintext. */
function decodeContainer(buffer) {
  const { frames, tornStart } = scanZstdFrames(buffer)
  const parts = []
  for (const frame of frames) {
    try {
      parts.push(zstdDecompressSync(buffer.subarray(frame.start, frame.end)).toString('utf8'))
    } catch (error) {
      throw new Error(`corrupt Zstandard session log: frame at byte ${frame.start} failed validation`, { cause: error })
    }
  }
  return { text: parts.join(''), tornStart }
}

/** Encode header + rows as the standard two-frame artifact body. */
function encodeLog(headerLine, rows) {
  const body = `${rows.map((row) => JSON.stringify(row)).join('\n')}\n`
  return Buffer.concat([
    zstdCompressSync(Buffer.from(headerLine), CHECKSUM_OPTIONS),
    zstdCompressSync(Buffer.from(body), CHECKSUM_OPTIONS),
  ])
}
//#endregion

//#region log parsing
/** Parse the JSONL plaintext into a header line plus one parsed object per row. */
function parseLogText(text) {
  const lines = text.split('\n')
  const first = lines[0] ?? ''
  if (!first.startsWith('{"type":"session"')) throw new Error('not a dsh session log')
  let header
  try { header = JSON.parse(first) } catch (error) { throw new Error('corrupt session log: header line is not valid JSON', { cause: error }) }
  const rows = []
  const unparsableLines = []
  let lastGoodLine = 1
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i]
    if (line.trim() === '') continue
    try { rows.push(JSON.parse(line)); lastGoodLine = i + 1 } catch { unparsableLines.push(i + 1) }
  }
  return { headerLine: `${first}\n`, header, rows, unparsableLines, lastGoodLine }
}

/**
 * Read one stored session log: frames → plaintext → header + rows.
 * @param file - absolute path of a session log artifact.
 * @returns parsed log with `torn` set when the container ends mid-frame, plus
 *   the line numbers that hold no parsable row and the last good line.
 */
export function readLogFile(file) {
  const { text, tornStart } = decodeContainer(readFileSync(file))
  return { ...parseLogText(text), torn: tornStart !== undefined, file }
}

/**
 * Whether the unparsable rows of a parsed log form a recoverable tail (every
 * malformed line sits after the last good row) rather than interior corruption.
 * @param parsed - result of {@link readLogFile}.
 * @returns Whether the unparsable rows are all trailing.
 */
export function hasOnlyTrailingGarbage(parsed) {
  if (parsed.unparsableLines.length === 0) return false
  return parsed.unparsableLines.every((line) => line > parsed.lastGoodLine)
}
//#endregion

//#region validation (dsh's own code paths)
/** Fold a restored current-format artifact through dsh's real TokenMeter. */
function meterOver(artifact) {
  const { Session, SessionId, SessionLogOffset } = dshPackage('dsh-session')
  const meterMod = dshPackage('dsh-token-meter')
  const TokenMeter = meterMod.default ?? meterMod
  const session = Session.fromRestore(
    SessionId(artifact.header.id),
    artifact.events,
    artifact.header,
    SessionLogOffset(artifact.inheritedEventCount ?? 0),
    'detached',
  )
  const meter = Object.create(TokenMeter.prototype)
  meter.states = new WeakMap()
  // The fold only needs a service face; no llm service is mounted here, so
  // image pricing and request-time file projection stay undefined exactly as
  // they would be for a session without those route features.
  meter.ctx = { get: () => undefined }
  return TokenMeter.prototype.measure.call(meter, session)
}

/**
 * Validate a stored log the way the app does when it opens a session for write
 * or migrates it on a model switch: catalog restore through the released format
 * chain with STRICT recovery, installed-Session admission, then the TokenMeter.
 *
 * Strict recovery is deliberate. The reader path uses `recoverable`, which
 * records the first malformed row or seq gap and silently drops everything after
 * it — so a rewritten-head/stale-tail log *reads* as a shorter session while the
 * write/migration path throws on the same bytes. Only strict recovery surfaces
 * the failure the user actually sees, and a repair that passes strict is also
 * accepted by the lenient read path.
 *
 * @param header - parsed stored header (any supported generation).
 * @param rows - parsed storage rows as stored.
 * @returns `{ ok: true, events, version }` or `{ ok: false, error }`.
 */
export function checkLog(header, rows) {
  const { sessionFormatCatalog } = dshPackage('dsh-session-format-catalog')
  let artifact
  try {
    const restore = sessionFormatCatalog.createRestore(header, { recovery: 'strict', validation: 'transformed' })
    for (const row of rows) restore.decodeRow(row)
    artifact = restore.finish()
  } catch (error) {
    return { ok: false, error: `format: ${String(error?.message ?? error)}` }
  }
  try {
    meterOver(artifact)
  } catch (error) {
    return { ok: false, error: `replay: ${String(error?.message ?? error)}` }
  }
  return { ok: true, events: artifact.events.length, version: artifact.header.version }
}

/**
 * Validate one stored log file end to end: container + JSON rows + strict
 * replay. Rows that do not parse are damage the pure validator never sees, so
 * they are folded in here.
 * @param file - absolute path of a session log artifact.
 * @returns `{ ok: true, events, version, parsed }` or `{ ok: false, error }`.
 */
export function checkLogFile(file) {
  let parsed
  try {
    parsed = readLogFile(file)
  } catch (error) {
    return { ok: false, error: `container: ${String(error?.message ?? error)}` }
  }
  if (parsed.unparsableLines.length > 0) {
    return { ok: false, error: `rows: line ${parsed.unparsableLines.join(',')} is not a JSON row`, parsed }
  }
  if (parsed.torn) {
    return { ok: false, error: 'container: log ends inside an unfinished Zstandard frame', parsed }
  }
  const verdict = checkLog(parsed.header, parsed.rows)
  return { ...verdict, parsed }
}

/**
 * Whether a stored log is read as-is by the lenient reader path
 * (`recovery: "recoverable"`), even when strict validation rejects it. Used to
 * tell "damaged and visible" from "damaged but silently truncated".
 * @param header - parsed stored header.
 * @param rows - parsed storage rows as stored.
 * @returns `{ ok, events }` for the recoverable restore.
 */
export function checkLogRecoverable(header, rows) {
  const { sessionFormatCatalog } = dshPackage('dsh-session-format-catalog')
  try {
    const restore = sessionFormatCatalog.createRestore(header, { recovery: 'recoverable', validation: 'transformed' })
    for (const row of rows) restore.decodeRow(row)
    const artifact = restore.finish()
    return { ok: true, events: artifact.events.length }
  } catch (error) {
    return { ok: false, error: String(error?.message ?? error) }
  }
}

/**
 * Kept for API compatibility with 1.6.1: whether an event list replays cleanly.
 * The list is validated as a current-format body; the caller's own header is not
 * available here, so a synthetic v3 header is used.
 * @param evs - candidate event list.
 * @returns Whether the list passes admission and the TokenMeter.
 */
export function isClean(evs) {
  try {
    return checkLog({ type: 'session', version: 3, id: 'repair-check', createdAt: 0, cwd: '/tmp' }, evs).ok
  } catch { return false }
}
//#endregion

//#region repair
/** Row types that pack a run of chunk events into one line; not repairable here. */
const PACKED_ROW_TYPES = new Set(['text-chunks', 'reasoning-chunks', 'tool-call-chunks'])

/**
 * dsh's own `sourceEventSeqs` codec. The stored field is a compact list where a
 * number is one seq and `[start, end]` is a run, so citations must be decoded
 * before they can be inspected or remapped and re-encoded afterwards.
 * @returns `{ decodeSeqRanges, encodeSeqRanges }` from the installed Session package.
 */
function seqRangeCodec() {
  const { decodeSeqRanges, encodeSeqRanges } = dshPackage('dsh-session')
  return { decodeSeqRanges, encodeSeqRanges }
}

/**
 * Decode one row's citations into a flat seq list, or `undefined` when the
 * stored field is not a valid citation list at all (which is itself damage).
 */
function decodeCitations(row) {
  if (!Array.isArray(row.sourceEventSeqs)) return undefined
  try {
    return seqRangeCodec().decodeSeqRanges(row.sourceEventSeqs)
  } catch {
    return undefined
  }
}

/** Latest unclosed step region in `fixed` (scanning back to last boundary). */
function openStepOf(fixed) {
  for (let k = fixed.length - 1; k >= 0; k--) {
    const t = fixed[k].type
    if (t === 'step/start') return fixed[k]
    if (t === 'step/end') break
  }
  return null
}

/**
 * Repair one decoded row list in memory: merge stale-cursor seams, insert
 * missing step markers, drop invalid chunk citations, renumber seqs.
 * Returns a fresh list; the input is not mutated.
 * @param input - parsed storage rows as stored.
 * @returns repaired rows.
 */
export function repairEvents(input) {
  if (input.some((row) => PACKED_ROW_TYPES.has(row?.type))) {
    throw new Error('日志含打包 chunk 行（text-chunks/reasoning-chunks/tool-call-chunks），自动修复未覆盖该编码')
  }

  let evs = input

  // ── seam merge: first seq rewind marks a rewritten-head + stale-tail log ──
  let seamIdx = -1
  let prevSeq = null
  for (let i = 0; i < evs.length; i++) {
    if (prevSeq !== null && typeof evs[i].seq === 'number' && evs[i].seq <= prevSeq) { seamIdx = i; break }
    if (typeof evs[i].seq === 'number') prevSeq = evs[i].seq
  }
  // 记录尾部事件的旧 seq → 对象身份，等 step 插入、全局重编号后再重映射
  // （step 插入会改变行号，提前映射会指错位置）。
  let tailOldSeqToEvent = null
  let tailRows = null
  if (seamIdx >= 0) {
    const head = evs.slice(0, seamIdx)
    const tail = evs.slice(seamIdx)
    tailRows = new Set(tail)
    tailOldSeqToEvent = new Map(tail.map((e) => [e.seq, e]))
    evs = [...head, ...tail]
  }

  // ── step pairing: open a step before unmarked message/tool events, close at turn bounds ──
  const STEP_TYPES = new Set(['assistant/message', 'tool/call', 'tool/result', 'assistant/chunk'])
  const fixed = []
  for (const e of evs) {
    if (STEP_TYPES.has(e.type) && e.data && typeof e.data.turn === 'number' && typeof e.data.step === 'number') {
      const open = openStepOf(fixed)
      if (!open || open.data.turn !== e.data.turn || open.data.step !== e.data.step) {
        // meter only enforces pairing order: close the old step first, even across turns
        if (open) fixed.push({ type: 'step/end', time: e.time, data: { turn: open.data.turn, step: open.data.step } })
        fixed.push({ type: 'step/start', time: e.time, data: { turn: e.data.turn, step: e.data.step } })
      }
    }
    if (e.type === 'turn/start' || e.type === 'turn/end') {
      const open = openStepOf(fixed)
      if (open) fixed.push({ type: 'step/end', time: e.time, data: { turn: open.data.turn, step: open.data.step } })
    }
    fixed.push(e)
  }

  fixed.forEach((e, i) => { e.seq = i })

  // ── seam citation remap: now that positions are final, translate each TAIL
  // row's stale seq citations into the final index of the same event. Head rows
  // keep their own (already correct) numbering — remapping them would resolve
  // colliding seqs to the duplicated tail event instead. ──
  if (tailOldSeqToEvent !== null) {
    const { encodeSeqRanges } = seqRangeCodec()
    const eventToFinal = new Map(fixed.map((e, i) => [e, i]))
    for (const e of fixed) {
      if (!tailRows.has(e)) continue
      if (!Array.isArray(e.sourceEventSeqs)) continue
      const decoded = decodeCitations(e)
      if (decoded === undefined) { delete e.sourceEventSeqs; continue }
      const mapped = decoded.map((s) => {
        const target = tailOldSeqToEvent.get(s)
        const final = target === undefined ? undefined : eventToFinal.get(target)
        return final === undefined ? s : final // unresolved: keep, strict validation decides
      })
      e.sourceEventSeqs = encodeSeqRanges(mapped)
    }
  }

  // ── citation hygiene: an assistant/message citation must name an
  // assistant/chunk row; undecodable citation lists are dropped outright. ──
  const { encodeSeqRanges } = seqRangeCodec()
  for (const e of fixed) {
    if (e.type !== 'assistant/message' || !Array.isArray(e.sourceEventSeqs)) continue
    const decoded = decodeCitations(e)
    if (decoded === undefined) { delete e.sourceEventSeqs; continue }
    const valid = decoded.filter((idx) => fixed[idx]?.type === 'assistant/chunk')
    if (valid.length !== decoded.length) {
      if (valid.length === 0) delete e.sourceEventSeqs
      else e.sourceEventSeqs = encodeSeqRanges(valid)
    } else if (decoded.length > 1 || e.sourceEventSeqs.some((entry) => Array.isArray(entry))) {
      e.sourceEventSeqs = encodeSeqRanges(valid)
    }
  }

  return fixed.map((e) => JSON.parse(JSON.stringify(e)))
}

/** Alias for {@link repairEvents}: rows in, repaired rows out. */
export const repairRows = repairEvents
//#endregion

//#region store scan
/**
 * Version of a canonical generation log name, or `undefined` when the name is
 * not a canonical stored log (`session.jsonl.zstd` is v0).
 */
function generationVersionOf(fileName, compression = 'zstd') {
  const suffix = compression === 'zstd' ? '.zstd' : ''
  if (suffix !== '' && !fileName.endsWith(suffix)) return undefined
  const base = suffix === '' ? fileName : fileName.slice(0, -suffix.length)
  try {
    const { parseSessionFormatLogFilename } = dshPackage('dsh-session-format')
    return parseSessionFormatLogFilename(base, compression)
  } catch {
    return undefined
  }
}

/** Every canonical session log under `<root>/<workspace>/<session>/`. */
function listSessionLogs(root) {
  const found = []
  if (!existsSync(root)) return found
  for (const ws of readdirSync(root)) {
    const wp = join(root, ws)
    let wsStat; try { wsStat = statSync(wp) } catch { continue }
    if (!wsStat.isDirectory()) continue
    for (const sessionId of readdirSync(wp)) {
      const dir = join(wp, sessionId)
      let dirStat; try { dirStat = statSync(dir) } catch { continue }
      if (!dirStat.isDirectory()) continue
      for (const name of readdirSync(dir)) {
        const version = generationVersionOf(name)
        if (version === undefined) continue
        found.push({ file: join(dir, name), dir, version })
      }
    }
  }
  return found
}

/** Pids holding `file` open, or `undefined` when none do / lsof is unavailable. */
function openBy(file) {
  try {
    const out = execFileSync('lsof', ['-t', file], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()
    return out === '' ? undefined : out.split('\n').join(',')
  } catch {
    return undefined
  }
}

/**
 * Scan (and optionally repair) every stored session log.
 *
 * `bad` entries are strings of the form `<file> — <reason>`, so the in-chat
 * command renders the reason without changing its handler.
 * @param options - `{ fix?: boolean, root?: string }`.
 * @returns `{ root, total, ok, bad, fixed, skipped }` summary.
 */
export function repairSessionStore(options = {}) {
  const root = options.root ?? join(homedir(), '.dsh', 'sessions')
  const logs = listSessionLogs(root)
  const bad = []
  const fixed = []
  const skipped = []
  let ok = 0

  const byDir = new Map()
  for (const entry of logs) {
    if (!byDir.has(entry.dir)) byDir.set(entry.dir, [])
    byDir.get(entry.dir).push(entry)
  }

  for (const entries of byDir.values()) {
    const selected = [...entries].sort((a, b) => b.version - a.version)[0]
    for (const entry of entries) {
      const verdict = checkLogFile(entry.file)
      const parsed = verdict.parsed
      if (verdict.ok) { ok += 1; continue }
      if (parsed === undefined) {
        if (verdict.error.startsWith('container: not a dsh session log')) continue // foreign file: ignore
        bad.push(`${entry.file} — ${verdict.error}`)
        continue
      }

      const superseded = entry === selected ? '' : '（已被更高版本取代，DSH 实际读取的是新版本）'
      bad.push(`${entry.file} — ${verdict.error}${superseded}`)
      if (options.fix !== true) continue

      const inUse = openBy(entry.file)
      if (inUse !== undefined) {
        skipped.push(`${entry.file} — 正被进程 ${inUse} 打开，已跳过（请先关闭该会话再修复）`)
        continue
      }
      if (parsed.torn) {
        skipped.push(`${entry.file} — 容器末尾有未完成帧，无法安全重写（可能是正在写入的会话）`)
        continue
      }
      // Rows that do not parse can only be dropped when they form a tail; a
      // malformed row in the middle means the events after it are unknown.
      if (parsed.unparsableLines.length > 0 && !hasOnlyTrailingGarbage(parsed)) {
        skipped.push(`${entry.file} — 第 ${parsed.unparsableLines.join(',')} 行不是合法 JSON 且不在文件末尾，无法安全重写`)
        continue
      }

      let repaired
      try {
        repaired = repairEvents(parsed.rows)
      } catch (error) {
        skipped.push(`${entry.file} — 未修复：${String(error?.message ?? error)}`)
        continue
      }
      const repairedVerdict = checkLog(parsed.header, repaired)
      if (!repairedVerdict.ok) {
        skipped.push(`${entry.file} — 修复后仍未通过校验：${repairedVerdict.error}`)
        continue
      }

      const backup = `${entry.file}.bak`
      if (!existsSync(backup)) copyFileSync(entry.file, backup)
      const temp = `${entry.file}.tmp-${process.pid}`
      writeFileSync(temp, encodeLog(parsed.headerLine, repaired))
      renameSync(temp, entry.file)

      // Never keep a write that does not read back clean.
      const writtenVerdict = checkLogFile(entry.file)
      if (!writtenVerdict.ok) {
        renameSync(backup, entry.file)
        skipped.push(`${entry.file} — 写入后校验失败，已回滚：${writtenVerdict.error}`)
        continue
      }
      fixed.push(entry.file)
    }
  }

  return { root, total: logs.length, ok, bad, fixed, skipped }
}

/** CLI entry: `dsh-codex-sync repair-sessions [--fix] [--root <dir>]`. */
export function runRepairCli(args) {
  const fix = args.fix === true
  const root = typeof args.root === 'string' ? args.root : undefined
  const summary = repairSessionStore({ fix, root })
  console.log(`scan: ${summary.total} logs in ${summary.root}, ${summary.ok} clean, ${summary.bad.length} damaged`)
  for (const f of summary.bad) console.log(`  BAD ${f}`)
  for (const f of summary.fixed) console.log(`  FIXED → ${f} (.bak kept)`)
  for (const f of summary.skipped) console.log(`  SKIP ${f}`)
  if (!fix && summary.bad.length > 0) console.log('\ndry run — rerun with --fix to repair')
}
//#endregion
