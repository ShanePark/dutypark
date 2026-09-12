import { execFileSync, spawnSync } from 'node:child_process'
import { cpSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

// Keep measurements beside regression tests so the benchmark exercises the real
// production functions and Vue component, using the same fixed input each run.
const frontend = fileURLToPath(new URL('..', import.meta.url))
const baselineRef = process.argv.find(argument => argument.startsWith('--baseline-ref='))?.slice('--baseline-ref='.length)
let temporaryProject
let benchmarkDirectory = frontend

try {
  if (baselineRef) {
    // Only the two measured modules come from the baseline revision. Tests,
    // fixtures, dependencies and compiler settings stay identical to this run.
    // The shared checkout is never overwritten while other tasks use it.
    temporaryProject = mkdtempSync(join(tmpdir(), 'dutypark-web-benchmark-'))
    benchmarkDirectory = temporaryProject
    for (const path of ['src', 'package.json', 'vite.config.ts', 'vitest.config.ts', 'tsconfig.json', 'tsconfig.app.json', 'tsconfig.node.json']) {
      cpSync(join(frontend, path), join(temporaryProject, path), { recursive: true })
    }
    symlinkSync(join(frontend, 'node_modules'), join(temporaryProject, 'node_modules'), 'dir')
    for (const path of ['src/utils/date.ts', 'src/components/duty/DutyCalendarContent.vue']) {
      writeFileSync(join(temporaryProject, path), execFileSync('git', ['show', `${baselineRef}:frontend/${path}`], { cwd: frontend }))
    }
  }

  console.log(`Benchmark source: ${baselineRef ?? 'working tree'}; TZ=Asia/Seoul`)
  const result = spawnSync(process.execPath, [
    'node_modules/vitest/vitest.mjs', 'run',
    'src/utils/date.performance.test.ts',
    'src/components/duty/DutyCalendarContent.performance.test.ts',
    '--maxWorkers=1', '--disableConsoleIntercept', '-t', 'measures',
  ], {
    cwd: benchmarkDirectory,
    env: { ...process.env, TZ: 'Asia/Seoul', DUTYPARK_PERFORMANCE_BENCHMARK: '1' },
    stdio: 'inherit',
  })

  if (result.error) throw result.error
  process.exitCode = result.status ?? 1
} finally {
  if (temporaryProject) rmSync(temporaryProject, { recursive: true, force: true })
}
