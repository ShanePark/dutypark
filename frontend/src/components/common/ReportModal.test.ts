import { describe, expect, it } from 'vitest'
import reportModal from './ReportModal.vue?raw'
import { REPORT_DETAIL_MAX_LENGTH, REPORT_REASONS } from '@/types/report'

describe('ReportModal', () => {
  it('offers every report reason as a radio option', () => {
    expect(REPORT_REASONS).toEqual([
      'SPAM',
      'HARASSMENT',
      'INAPPROPRIATE_CONTENT',
      'IMPERSONATION',
      'OTHER',
    ])
    expect(reportModal).toContain('type="radio"')
    for (const reason of REPORT_REASONS) {
      expect(reportModal, `missing reason label for ${reason}`).toContain(`${reason}:`)
    }
  })

  it('requires the detail text only when OTHER is selected', () => {
    expect(reportModal).toContain("const isDetailRequired = computed(() => reason.value === 'OTHER')")
    expect(reportModal).toContain('const isDetailMissing = computed(() => isDetailRequired.value && !detail.value.trim())')
    expect(reportModal).toContain("t('report.modal.detailRequired')")
  })

  it('caps the detail text at the contracted length', () => {
    expect(REPORT_DETAIL_MAX_LENGTH).toBe(500)
    expect(reportModal).toContain(':maxlength="REPORT_DETAIL_MAX_LENGTH"')
  })

  it('lets the reporter block the same user in one submission', () => {
    expect(reportModal).toContain('const alsoBlock = ref(false)')
    expect(reportModal).toContain('alsoBlock: alsoBlock.value')
    expect(reportModal).toContain("t('report.modal.alsoBlock')")
  })

  it('blocks submission until the form is valid', () => {
    expect(reportModal).toContain('if (!reason.value || isDetailMissing.value || props.isSubmitting) return')
    expect(reportModal).toContain(':disabled="isSubmitDisabled"')
  })

  it('stays above the day and to-do detail modals', () => {
    expect(reportModal).toContain('z-index="admin"')
  })
})
