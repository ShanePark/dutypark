import Swal from 'sweetalert2'

const defaultConfig = {
  confirmButtonColor: '#2563eb',
  cancelButtonColor: '#f3f4f6',
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
  const showError = (message: string, title = '오류') => {
    return Swal.fire({
      icon: 'error',
      title,
      text: message,
      confirmButtonText: '확인',
      confirmButtonColor: defaultConfig.confirmButtonColor,
    })
  }

  const showWarning = (message: string, title = '주의') => {
    return Swal.fire({
      icon: 'warning',
      title,
      text: message,
      confirmButtonText: '확인',
      confirmButtonColor: defaultConfig.confirmButtonColor,
    })
  }

  const showSuccess = (message: string, title = '성공') => {
    return Swal.fire({
      icon: 'success',
      title,
      text: message,
      confirmButtonText: '확인',
      confirmButtonColor: defaultConfig.confirmButtonColor,
    })
  }

  const showInfo = (message: string, title = '알림') => {
    return Swal.fire({
      icon: 'info',
      title,
      text: message,
      confirmButtonText: '확인',
      confirmButtonColor: defaultConfig.confirmButtonColor,
    })
  }

  const confirm = (message: string, title = '확인') => {
    return Swal.fire({
      icon: 'question',
      title,
      text: message,
      showCancelButton: true,
      confirmButtonText: '확인',
      cancelButtonText: '취소',
      confirmButtonColor: defaultConfig.confirmButtonColor,
    }).then((result) => result.isConfirmed)
  }

  const confirmDelete = (message: string, title = '삭제 확인') => {
    return Swal.fire({
      icon: 'warning',
      title,
      text: message,
      showCancelButton: true,
      confirmButtonText: '삭제',
      cancelButtonText: '취소',
      confirmButtonColor: '#dc2626',
    }).then((result) => result.isConfirmed)
  }

  const toastSuccess = (message: string) => {
    const checkIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>`
    return Toast.fire({
      icon: undefined,
      title: `<span class="toast-with-icon">${checkIcon}<span>${message}</span></span>`,
      customClass: {
        popup: 'colored-toast colored-toast-success',
      },
    })
  }

  const toastError = (message: string) => {
    return Toast.fire({
      icon: undefined,
      title: message,
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
    confirmDelete,
    toastSuccess,
    toastError,
  }
}
