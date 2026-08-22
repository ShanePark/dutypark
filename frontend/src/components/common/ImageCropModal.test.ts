import { describe, expect, it } from 'vitest'
import imageCropModal from './ImageCropModal.vue?raw'
import { hasCropChanged, type CropResultLike, type CropSnapshot } from './imageCropModalState'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'

const script = imageCropModal.slice(0, imageCropModal.indexOf('<template>'))
const template = imageCropModal.slice(
  imageCropModal.indexOf('<template>'),
  imageCropModal.indexOf('<style'),
)

describe('ImageCropModal save state', () => {
  it('keeps saving disabled until the image or crop is changed', () => {
    expect(script).toContain('const hasCropChanges = ref(false)')
    expect(script).toContain('function onCropperReady()')
    expect(script).toContain('function onCropperChange(result: CropResultLike)')
    expect(script).toContain('if (!isCropperReady.value || !isEditingExistingPhoto.value) return')
    expect(script).toContain('Math.abs(zoom.value - minZoom) > 0.0001')
    expect(script).toContain('updateCropChangeState()')
    expect(script).toContain('if (isProcessing.value || !hasImage.value || !hasChanges.value) return')
    expect(template).toContain('@ready="onCropperReady"')
    expect(template).toContain('@change="onCropperChange"')
    expect(template).toContain(':disabled="isProcessing || !hasImage || !hasChanges"')
  })

  it('compares the current crop to the ready-state baseline', () => {
    const initial: CropSnapshot = {
      coordinates: { width: 100, height: 100, top: 10, left: 20 },
      visibleArea: { width: 200, height: 200, top: 0, left: 0 },
    }
    const unchanged: CropResultLike = {
      coordinates: { ...initial.coordinates },
      visibleArea: { ...initial.visibleArea },
    }

    expect(hasCropChanged(initial, unchanged)).toBe(false)
    expect(
      hasCropChanged(initial, {
        ...unchanged,
        visibleArea: { ...unchanged.visibleArea, left: 999 },
      }),
    ).toBe(false)
    expect(
      hasCropChanged(initial, {
        ...unchanged,
        coordinates: { ...unchanged.coordinates, left: 21 },
      }),
    ).toBe(true)
  })
})

describe('ImageCropModal default image action', () => {
  it('uses the default-image wording for the reset action and its feedback', () => {
    expect(template).toContain("t('profilePhoto.useDefault')")
    expect(script).toContain('RotateCcw')
    expect(template).toContain('class="btn-default-image"')

    expect(ko.profilePhoto.useDefault).toBe('기본 이미지로 변경')
    expect(en.profilePhoto.useDefault).toBe('Use default image')
    expect(ko.profilePhoto.deleteTitle).toBe('기본 이미지로 변경')
    expect(ko.profilePhoto.deleteConfirm).toBe('프로필 사진을 기본 이미지로 변경하시겠습니까?')
    expect(ko.profilePhoto.deleted).toBe('프로필 사진이 기본 이미지로 변경되었습니다.')
    expect(ko.profilePhoto.deleteFailed).toContain('기본 이미지로 변경하지 못했습니다.')
    expect(en.profilePhoto.deleteConfirm).toBe('Change your profile photo to the default image?')
    expect(en.profilePhoto.deleted).toBe('Your profile photo is now set to the default image.')
    expect(en.profilePhoto.deleteFailed).toContain('default image')
  })
})
