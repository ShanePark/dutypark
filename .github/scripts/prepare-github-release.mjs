import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'

function requiredEnv(name) {
  const value = process.env[name]
  if (!value) {
    throw new Error(`${name} is required`)
  }
  return value
}

function optionalEnv(name) {
  return process.env[name] || ''
}

function runGh(args) {
  return execFileSync('gh', args, {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 10,
  }).trim()
}

function decodeI18nLiteral(text) {
  return text
    .replaceAll("{'@'}", '@')
    .replaceAll("{'{'}", '{')
    .replaceAll("{'}'}", '}')
}

function parseJsonStringFromLine(line) {
  const match = line.match(/"((?:[^"\\]|\\.)*)"/)
  return match ? decodeI18nLiteral(JSON.parse(match[0])) : null
}

function readInAppReleaseNoteMeta(prNumber) {
  const metaPath = path.join(process.cwd(), 'frontend', 'src', 'releaseNotes', 'meta.ts')
  if (!fs.existsSync(metaPath)) {
    return null
  }

  const lines = fs.readFileSync(metaPath, 'utf8').split('\n')
  const startIndex = lines.findIndex(line => line.includes(`id: "pr-${prNumber}"`))
  if (startIndex < 0) {
    return null
  }

  const note = {
    version: '',
  }

  for (const line of lines.slice(startIndex + 1)) {
    const trimmed = line.trim()
    if (trimmed === '},' || trimmed === '}') {
      break
    }

    if (trimmed.startsWith('version:')) {
      note.version = parseJsonStringFromLine(line) ?? ''
    }
  }

  return note.version ? note : null
}

function readInAppReleaseNote(prNumber, locale = 'en') {
  const messagePath = path.join(
    process.cwd(),
    'frontend',
    'src',
    'releaseNotes',
    'messages',
    `${locale}.ts`,
  )

  if (!fs.existsSync(messagePath)) {
    return null
  }

  const lines = fs.readFileSync(messagePath, 'utf8').split('\n')
  const startIndex = lines.findIndex(line => line.includes(`"pr-${prNumber}": {`))
  if (startIndex < 0) {
    return null
  }

  const note = {
    title: '',
    summary: '',
    changes: [],
  }
  let inChanges = false

  for (const line of lines.slice(startIndex + 1)) {
    const trimmed = line.trim()

    if (trimmed === '},' || trimmed === '}') {
      break
    }

    if (trimmed.startsWith('title:')) {
      note.title = parseJsonStringFromLine(line) ?? ''
      continue
    }

    if (trimmed.startsWith('summary:')) {
      note.summary = parseJsonStringFromLine(line) ?? ''
      continue
    }

    if (trimmed.startsWith('changes: [')) {
      inChanges = true
      continue
    }

    if (inChanges && trimmed.startsWith(']')) {
      inChanges = false
      continue
    }

    if (inChanges) {
      const change = parseJsonStringFromLine(line)
      if (change) {
        note.changes.push(change)
      }
    }
  }

  return note.title && note.summary ? note : null
}

function releaseNotesFromInAppEntry(note, pr) {
  const changes = note.changes.map(change => `- ${change}`).join('\n')

  return `## Summary
- ${note.summary}

## Changes
${changes}

## Pull Request
- [#${pr.number}](${pr.url})
`
}

function readPrNumberFromTarget(target) {
  const repository = requiredEnv('GITHUB_REPOSITORY')
  const pullRequests = JSON.parse(runGh([
    'api',
    `repos/${repository}/commits/${target}/pulls`,
    '-H',
    'Accept: application/vnd.github+json',
  ]))
  const mergedPullRequest = pullRequests.find(pullRequest => pullRequest.merged_at)

  if (!mergedPullRequest) {
    throw new Error(`No merged PR found for commit ${target}`)
  }

  return String(mergedPullRequest.number)
}

function writeOutput(key, value) {
  const outputPath = requiredEnv('GITHUB_OUTPUT')
  fs.appendFileSync(outputPath, `${key}<<EOF\n${value}\nEOF\n`)
}

const targetFromEnv = optionalEnv('TARGET_SHA')
let prNumber = optionalEnv('PR_NUMBER')
if (!prNumber && !targetFromEnv) {
  throw new Error('PR_NUMBER or TARGET_SHA is required')
}

if (!prNumber) {
  prNumber = readPrNumberFromTarget(targetFromEnv)
}

const pr = JSON.parse(runGh([
  'pr',
  'view',
  prNumber,
  '--json',
  'number,url,mergedAt,mergeCommit,headRefName,author',
]))

if (!pr.mergedAt) {
  throw new Error(`PR #${prNumber} is not merged`)
}

const target = targetFromEnv || pr.mergeCommit?.oid
if (!target) {
  throw new Error(`PR #${prNumber} does not have a merge commit SHA`)
}

const authorLogin = pr.author?.login || ''
const isDependabotPr = authorLogin === 'dependabot[bot]' || pr.headRefName?.startsWith('dependabot/')

if (isDependabotPr) {
  writeOutput('skipped', 'true')
  writeOutput('reason', `PR #${pr.number} is a Dependabot dependency update`)
  writeOutput('target', target)
  process.exit(0)
}

const inAppReleaseNoteMeta = readInAppReleaseNoteMeta(pr.number)
const inAppReleaseNote = readInAppReleaseNote(pr.number)

if (!inAppReleaseNoteMeta?.version) {
  throw new Error(`Missing in-app release note metadata for PR #${pr.number}`)
}

if (!inAppReleaseNote) {
  throw new Error(`Missing English in-app release note copy for PR #${pr.number}`)
}

const tag = inAppReleaseNoteMeta.version

let releaseExists = false
try {
  execFileSync('gh', ['release', 'view', tag, '--json', 'tagName'], {
    stdio: 'ignore',
  })
  releaseExists = true
} catch {
  releaseExists = false
}

const notesFile = path.join(os.tmpdir(), `dutypark-release-${tag}.md`)
fs.writeFileSync(notesFile, releaseNotesFromInAppEntry(inAppReleaseNote, pr))

writeOutput('tag', tag)
writeOutput('title', `${tag} - ${inAppReleaseNote.title}`)
writeOutput('target', target)
writeOutput('notes_file', notesFile)
writeOutput('exists', String(releaseExists))
writeOutput('skipped', 'false')
