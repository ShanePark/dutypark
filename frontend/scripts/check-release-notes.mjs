import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { baseCompile } from '@intlify/message-compiler'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
const releaseNotesRoot = path.join(root, 'src', 'releaseNotes')
const metaPath = path.join(releaseNotesRoot, 'meta.ts')
const messageDir = path.join(releaseNotesRoot, 'messages')
const locales = ['en', 'ko', 'ja', 'zh', 'es']

function fail(message) {
  console.error(message)
  process.exitCode = 1
}

function read(filePath) {
  return fs.readFileSync(filePath, 'utf8')
}

function extractDoubleQuotedStrings(line) {
  const matches = []
  const pattern = /"((?:[^"\\]|\\.)*)"/g
  let match

  while ((match = pattern.exec(line)) !== null) {
    matches.push(match[0])
  }

  return matches
}

function validateMessageCompilation(locale, text) {
  text.split('\n').forEach((line, index) => {
    for (const rawString of extractDoubleQuotedStrings(line)) {
      const message = JSON.parse(rawString)
      const errors = []
      baseCompile(message, {
        onError(error) {
          errors.push(error.message)
        },
      })

      if (errors.length > 0) {
        fail(`${locale}:${index + 1}: invalid i18n message "${message}": ${errors.join(', ')}`)
      }
    }
  })
}

const meta = read(metaPath)
const ids = [...meta.matchAll(/id: "([^"]+)"/g)].map(match => match[1])
const versions = [...meta.matchAll(/version: "([^"]+)"/g)].map(match => match[1])
const prs = [...meta.matchAll(/pr: (\d+)/g)].map(match => Number(match[1]))

if (ids.length === 0) {
  fail('No release note metadata entries found.')
}

if (new Set(ids).size !== ids.length) {
  fail('Duplicate release note ids found in meta.ts.')
}

if (new Set(versions).size !== versions.length) {
  fail('Duplicate release note versions found in meta.ts.')
}

if (new Set(prs).size !== prs.length) {
  fail('Duplicate PR numbers found in meta.ts.')
}

for (const locale of locales) {
  const messagePath = path.join(messageDir, `${locale}.ts`)
  const text = read(messagePath)
  validateMessageCompilation(locale, text)

  const localeIds = [...text.matchAll(/"pr-\d+": \{/g)].map(match => match[0].slice(1, -4))
  const missing = ids.filter(id => !localeIds.includes(id))
  const extra = localeIds.filter(id => !ids.includes(id))

  if (missing.length > 0) {
    fail(`${locale}: missing release note entries: ${missing.join(', ')}`)
  }

  if (extra.length > 0) {
    fail(`${locale}: extra release note entries: ${extra.join(', ')}`)
  }
}

if (!process.exitCode) {
  console.log(`Release notes OK: ${ids.length} PR entries across ${locales.length} locales.`)
}
