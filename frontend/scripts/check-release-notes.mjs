import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repositoryRoot = path.resolve(__dirname, '..', '..')
const releaseNotesPath = path.join(repositoryRoot, 'src', 'main', 'resources', 'public-content', 'release-notes.json')
const locales = ['en', 'ko']
const categories = ['feature', 'improvement', 'fix', 'maintenance', 'security']
const areas = [
  'admin', 'attachments', 'auth', 'calendar', 'dashboard', 'docs', 'duty', 'friends', 'guide', 'infra',
  'localization', 'maintenance', 'notifications', 'policy', 'profile', 'schedule', 'security', 'team', 'todo', 'ui',
]

function fail(message) {
  console.error(message)
  process.exitCode = 1
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0
}

function duplicates(values) {
  return [...new Set(values.filter((value, index) => values.indexOf(value) !== index))]
}

function sameValues(actual, expected) {
  return actual.length === expected.length && actual.every(value => expected.includes(value))
}

let releaseNotes
try {
  releaseNotes = JSON.parse(fs.readFileSync(releaseNotesPath, 'utf8'))
} catch (error) {
  fail(`Unable to read canonical release notes at ${releaseNotesPath}: ${error.message}`)
}

if (releaseNotes) {
  if (releaseNotes.schemaVersion !== 1) fail('Release note schemaVersion must be 1.')
  if (Object.hasOwn(releaseNotes, 'contentVersion')) {
    fail('Do not author contentVersion; the backend derives it from the canonical JSON SHA-256 digest.')
  }
  if (!Array.isArray(releaseNotes.items) || releaseNotes.items.length === 0) fail('No release note entries found.')

  const items = Array.isArray(releaseNotes.items) ? releaseNotes.items : []
  for (const field of ['id', 'version', 'pr']) {
    const duplicateValues = duplicates(items.map(item => item[field]))
    if (duplicateValues.length > 0) fail(`Duplicate release note ${field} values found: ${duplicateValues.join(', ')}`)
  }

  items.forEach((item, index) => {
    const prefix = `release note item ${index + 1}`
    if (item.id !== `pr-${item.pr}`) fail(`${prefix}: id must match pr-${item.pr}.`)
    if (!/^\d{4}\.\d{2}\.\d{2}(\.\d{2})?$/.test(item.version)) fail(`${prefix}: invalid version ${item.version}.`)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(item.date)) fail(`${prefix}: invalid date ${item.date}.`)
    if (!item.version?.startsWith(item.date?.replaceAll('-', '.'))) fail(`${prefix}: version must start with its date.`)
    if (item.url !== `https://github.com/ShanePark/dutypark/pull/${item.pr}`) fail(`${prefix}: pull request URL does not match PR #${item.pr}.`)
    if (!categories.includes(item.category)) fail(`${prefix}: unknown category ${item.category}.`)
    if (!Array.isArray(item.areas) || item.areas.length === 0) {
      fail(`${prefix}: areas must not be empty.`)
    } else {
      const invalidAreas = item.areas.filter(area => !areas.includes(area))
      if (invalidAreas.length > 0) fail(`${prefix}: unknown areas ${invalidAreas.join(', ')}.`)
      if (new Set(item.areas).size !== item.areas.length) fail(`${prefix}: duplicate areas found.`)
    }
    if (index > 0 && items[index - 1].date < item.date) fail(`${prefix}: release notes must remain newest first.`)
  })

  const localized = releaseNotes.locales && typeof releaseNotes.locales === 'object' ? releaseNotes.locales : {}
  if (!sameValues(Object.keys(localized), locales)) fail(`Release note locales must be exactly: ${locales.join(', ')}.`)

  const ids = items.map(item => item.id)
  for (const locale of locales) {
    const localeContent = localized[locale]
    if (!localeContent) continue
    const labels = localeContent.labels || {}
    if (!isNonEmptyString(labels.title) || !isNonEmptyString(labels.latest)) fail(`${locale}: title and latest labels are required.`)
    for (const category of categories) {
      if (!isNonEmptyString(labels.categoryLabels?.[category])) fail(`${locale}: missing category label ${category}.`)
    }
    for (const area of areas) {
      if (!isNonEmptyString(labels.areaLabels?.[area])) fail(`${locale}: missing area label ${area}.`)
    }

    const entries = localeContent.entries && typeof localeContent.entries === 'object' ? localeContent.entries : {}
    const entryIds = Object.keys(entries)
    const missing = ids.filter(id => !entryIds.includes(id))
    const extra = entryIds.filter(id => !ids.includes(id))
    if (missing.length > 0) fail(`${locale}: missing release note entries: ${missing.join(', ')}`)
    if (extra.length > 0) fail(`${locale}: extra release note entries: ${extra.join(', ')}`)

    for (const id of ids) {
      const copy = entries[id]
      if (!copy) continue
      if (!isNonEmptyString(copy.title) || !isNonEmptyString(copy.summary)) fail(`${locale}:${id}: title and summary are required.`)
      if (!Array.isArray(copy.changes) || copy.changes.length === 0 || !copy.changes.every(isNonEmptyString)) {
        fail(`${locale}:${id}: at least one non-empty change is required.`)
      }
    }
  }

  if (!process.exitCode) console.log(`Release notes OK: ${items.length} PR entries across ${locales.length} locales.`)
}
