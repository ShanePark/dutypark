import { describe, expect, it } from 'vitest'
import friendSearchModal from './FriendSearchModal.vue?raw'
import friendsView from '@/views/member/FriendsView.vue?raw'
import dashboardView from '@/views/dashboard/DashboardView.vue?raw'

const styleStart = friendSearchModal.indexOf('<style')
const template = friendSearchModal.slice(friendSearchModal.indexOf('<template>'), styleStart > -1 ? styleStart : friendSearchModal.length)
const style = styleStart > -1 ? friendSearchModal.slice(styleStart) : ''

function ruleFor(selector: string) {
  const start = style.indexOf(`${selector} {`)
  expect(start, `missing rule for ${selector}`).toBeGreaterThan(-1)
  const end = style.indexOf('}', start)
  return style.slice(start, end)
}

// The empty message describes the last search that ran, not the live field.
describe('FriendSearchModal empty state', () => {
  it('reports no matches only after a submitted search', () => {
    expect(friendSearchModal).toContain('searchedKeyword: string | null')
    expect(template).toContain(
      "searchedKeyword !== null ? t('friendSearchModal.emptyWithKeyword') : t('friendSearchModal.emptyWithoutKeyword')",
    )
    expect(template).not.toContain("keyword.trim() ? t('friendSearchModal.emptyWithKeyword')")
  })
})

describe('FriendSearchModal search field', () => {
  it('keeps the placeholder clear of the leading search icon', () => {
    const inputStart = template.indexOf('<input')
    const inputEnd = template.indexOf('/>', inputStart)
    const input = template.slice(inputStart, inputEnd)

    expect(input).toContain('friend-search-modal__search-input')

    const inputRule = ruleFor('.friend-search-modal__search-input')
    expect(inputRule).toContain('padding: 0.75rem 1rem 0.75rem 2.75rem')
    expect(inputRule).toContain('border-radius: 0.75rem')
  })
})

/** Body of the script function `name`, up to the next top-level declaration. */
function functionBody(source: string, name: string) {
  const start = source.search(new RegExp(`^(async )?function ${name}\\(`, 'm'))
  expect(start, `missing function ${name}`).toBeGreaterThan(-1)
  const next = source.slice(start + 1).search(/^(async function|function|const|onMounted)\b/m)
  return next > -1 ? source.slice(start, start + 1 + next) : source.slice(start)
}

// Search runs only on submit, so paging continues the last search that ran,
// not whatever is in the keyword field now (matching iOS).
describe.each([
  ['FriendsView', friendsView],
  ['DashboardView', dashboardView],
])('%s friend search paging', (_name, view) => {
  const script = view.slice(0, view.indexOf('<template>'))

  it('remembers the keyword of the last search that ran', () => {
    expect(script).toContain('const searchedKeyword = ref<string | null>(null)')
    const search = functionBody(script, 'search')
    expect(search).toContain('async function search(keyword = searchKeyword.value, page = 0)')
    expect(search).toContain('friendApi.searchPossibleFriends(\n      keyword,\n      page,')
    expect(search).toContain('searchedKeyword.value = keyword')
    expect(search).toContain('searchPage.value = page')
    expect(functionBody(script, 'openSearchModal')).toContain('searchedKeyword.value = null')
  })

  it('treats an empty keyword as no search, like the disabled search button', () => {
    const search = functionBody(script, 'search')
    const guard = search.indexOf('if (!keyword.trim()) {')
    expect(guard).toBeGreaterThan(-1)
    expect(guard).toBeLessThan(search.indexOf('friendApi.searchPossibleFriends'))
    expect(search.slice(guard, search.indexOf('return', guard))).toContain('searchedKeyword.value = null')
  })

  it('passes the submitted keyword to the modal', () => {
    expect(view).toContain(':searched-keyword="searchedKeyword"')
  })

  it('pages through the submitted keyword, not the live field', () => {
    const goToPage = functionBody(script, 'goToPage')
    expect(goToPage).toContain('if (searchedKeyword.value === null) return')
    expect(goToPage).toContain('search(searchedKeyword.value, page)')
    expect(goToPage).not.toContain('searchKeyword.value')
  })
})
