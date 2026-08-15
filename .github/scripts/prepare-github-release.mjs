import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repositoryRoot = path.resolve(__dirname, '..', '..')
const releaseNotesPath = path.join(repositoryRoot, 'src', 'main', 'resources', 'public-content', 'release-notes.json')

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

function readCanonicalReleaseNotes() {
  if (!fs.existsSync(releaseNotesPath)) {
    throw new Error(`Missing canonical release notes: ${releaseNotesPath}`)
  }
  return JSON.parse(fs.readFileSync(releaseNotesPath, 'utf8'))
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

const canonicalReleaseNotes = readCanonicalReleaseNotes()
const matchingNotes = canonicalReleaseNotes.items?.filter(note => note.pr === pr.number) || []
const inAppReleaseNoteMeta = matchingNotes.length === 1 ? matchingNotes[0] : null
const inAppReleaseNote = inAppReleaseNoteMeta
  ? canonicalReleaseNotes.locales?.en?.entries?.[inAppReleaseNoteMeta.id]
  : null

if (!inAppReleaseNoteMeta?.version) {
  throw new Error(`Missing in-app release note metadata for PR #${pr.number}`)
}

if (
  !inAppReleaseNote?.title ||
  !inAppReleaseNote?.summary ||
  !Array.isArray(inAppReleaseNote.changes) ||
  inAppReleaseNote.changes.length === 0
) {
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
