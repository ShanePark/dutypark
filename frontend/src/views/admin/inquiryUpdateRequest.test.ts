import { describe, expect, it } from 'vitest'
import { buildInquiryUpdateRequest } from './inquiryUpdateRequest'

describe('buildInquiryUpdateRequest', () => {
  it('includes a newly written answer while preserving the requested status', () => {
    expect(buildInquiryUpdateRequest('CLOSED', '  확인함  ', '  새 답변  ', null)).toEqual({
      status: 'CLOSED',
      memo: '확인함',
      answer: '새 답변',
    })
  })

  it('omits an unchanged answer when the status is toggled', () => {
    expect(buildInquiryUpdateRequest('OPEN', '  다시 확인  ', '  기존 답변  ', '기존 답변')).toEqual({
      status: 'OPEN',
      memo: '다시 확인',
      answer: undefined,
    })
  })

  it('keeps an empty memo so clearing the box clears the stored memo', () => {
    expect(buildInquiryUpdateRequest('OPEN', '   ', '', null)).toEqual({
      status: 'OPEN',
      memo: '',
      answer: undefined,
    })
  })
})
