import Swal from 'sweetalert2'
import { translateGlobal } from '@/i18n'

function readCssVar(name: string, fallback: string): string {
  if (typeof window === 'undefined') return fallback
  const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  return value || fallback
}

function getSwalColors() {
  return {
    confirmButtonColor: readCssVar('--dp-accent', 'var(--dp-accent)'),
    cancelButtonColor: readCssVar('--dp-bg-tertiary', 'var(--dp-bg-tertiary)'),
    dangerButtonColor: readCssVar('--dp-danger-hover', 'var(--dp-danger-hover)'),
  }
}

const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 2000,
  timerProgressBar: false,
  showClass: {
    popup: 'swal2-show',
  },
  hideClass: {
    popup: 'swal2-hide',
  },
  customClass: {
    popup: 'colored-toast',
  },
})

export function useSwal() {
  type ChoiceResult = 'confirm' | 'deny' | 'cancel'

  const showError = (message: string, title = translateGlobal('common.swal.error')) => {
    const colors = getSwalColors()
    return Swal.fire({
      icon: 'error',
      title,
      text: message,
      confirmButtonText: translateGlobal('common.actions.confirm'),
      confirmButtonColor: colors.confirmButtonColor,
    })
  }

  const showWarning = (message: string, title = translateGlobal('common.swal.warning')) => {
    const colors = getSwalColors()
    return Swal.fire({
      icon: 'warning',
      title,
      text: message,
      confirmButtonText: translateGlobal('common.actions.confirm'),
      confirmButtonColor: colors.confirmButtonColor,
    })
  }

  const showSuccess = (message: string, title = translateGlobal('common.swal.success')) => {
    const colors = getSwalColors()
    return Swal.fire({
      icon: 'success',
      title,
      text: message,
      confirmButtonText: translateGlobal('common.actions.confirm'),
      confirmButtonColor: colors.confirmButtonColor,
    })
  }

  const showInfo = (message: string, title = translateGlobal('common.swal.info')) => {
    const colors = getSwalColors()
    return Swal.fire({
      icon: 'info',
      title,
      text: message,
      confirmButtonText: translateGlobal('common.actions.confirm'),
      confirmButtonColor: colors.confirmButtonColor,
    })
  }

  const confirm = (
    message: string,
    title = translateGlobal('common.swal.confirm'),
    confirmButtonText = title,
    cancelButtonText = translateGlobal('common.actions.cancel'),
    options: { animation?: boolean } = {},
  ) => {
    const colors = getSwalColors()
    return Swal.fire({
      icon: 'question',
      title,
      text: message,
      showCancelButton: true,
      confirmButtonText,
      cancelButtonText,
      confirmButtonColor: colors.confirmButtonColor,
      cancelButtonColor: colors.cancelButtonColor,
      ...(options.animation === undefined ? {} : { animation: options.animation }),
    }).then((result) => result.isConfirmed)
  }

  const choose = (
    message: string,
    title: string,
    confirmButtonText: string,
    denyButtonText: string,
    cancelButtonText = translateGlobal('common.actions.cancel'),
  ): Promise<ChoiceResult> => {
    const colors = getSwalColors()
    return Swal.fire({
      icon: 'question',
      title,
      text: message,
      showConfirmButton: true,
      showDenyButton: true,
      showCancelButton: true,
      confirmButtonText,
      denyButtonText,
      cancelButtonText,
      confirmButtonColor: colors.confirmButtonColor,
      denyButtonColor: colors.cancelButtonColor,
      cancelButtonColor: colors.cancelButtonColor,
    }).then((result) => {
      if (result.isConfirmed) return 'confirm'
      if (result.isDenied) return 'deny'
      return 'cancel'
    })
  }

  const confirmDelete = (
    message: string,
    title = translateGlobal('common.swal.confirmDelete'),
    confirmButtonText = translateGlobal('common.actions.delete'),
  ) => {
    const colors = getSwalColors()
    return Swal.fire({
      icon: 'warning',
      title,
      text: message,
      showCancelButton: true,
      confirmButtonText,
      cancelButtonText: translateGlobal('common.actions.cancel'),
      confirmButtonColor: colors.dangerButtonColor,
      cancelButtonColor: colors.cancelButtonColor,
    }).then((result) => result.isConfirmed)
  }

  // Toast messages often interpolate user-provided names, so they must stay text (titleText), never HTML.
  // The success check icon is drawn by CSS on .colored-toast-success.
  const toastSuccess = (message: string) => {
    return Toast.fire({
      icon: undefined,
      titleText: message,
      customClass: {
        popup: 'colored-toast colored-toast-success',
      },
    })
  }

  const toastInfo = (message: string) => {
    return Toast.fire({
      icon: undefined,
      titleText: message,
      customClass: {
        popup: 'colored-toast colored-toast-info',
      },
    })
  }

  const toastError = (message: string) => {
    return Toast.fire({
      icon: undefined,
      titleText: message,
      customClass: {
        popup: 'colored-toast colored-toast-error',
      },
    })
  }

  return {
    showError,
    showWarning,
    showSuccess,
    showInfo,
    confirm,
    choose,
    confirmDelete,
    toastSuccess,
    toastInfo,
    toastError,
  }
}
