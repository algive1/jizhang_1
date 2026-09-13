// Health check of the whole DSH session store using the patched repair module:
// every generation log is migrated through dsh's own format catalog with STRICT
// recovery and folded through the real TokenMeter.
//
// Run:
//   ELECTRON_RUN_AS_NODE=1 DSH_CHECKOUT="$DSH_ASAR/node_modules" \
//     "$DSH_ASAR/../MacOS/DSH Desktop" tests/verify-store.mjs
import { repairSessionStore, checkLogRecoverable, readLogFile } from '../session-repair.mjs'

const summary = repairSessionStore({ fix: false })
console.log(`root: ${summary.root}`)
console.log(`scan: ${summary.total} logs, ${summary.ok} clean, ${summary.bad.length} damaged`)
for (const entry of summary.bad) console.log(`  BAD ${entry}`)

// For every damaged log, also report what the lenient reader path sees, so a
// "silently truncated" session is distinguishable from a visible failure.
for (const entry of summary.bad) {
  const file = entry.split(' — ')[0]
  try {
    const parsed = readLogFile(file)
    const lenient = checkLogRecoverable(parsed.header, parsed.rows)
    console.log(`  lenient read of ${file}: ${lenient.ok ? `${lenient.events} events (tail dropped)` : `error ${lenient.error}`}`)
  } catch (error) {
    console.log(`  lenient read of ${file}: unreadable (${String(error?.message ?? error)})`)
  }
}
process.exitCode = summary.bad.length === 0 ? 0 : 1
