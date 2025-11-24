import Swal from 'sweetalert2'

const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
})

export function useSwal() {
  const showError = (message: string, title = '오류') => {
    return Swal.fire({
      icon: 'error',
      title,
      text: message,
      confirmButtonText: '확인',
    })
  }

  const showWarning = (message: string, title = '주의') => {
    return Swal.fire({
      icon: 'warning',
      title,
      text: message,
      confirmButtonText: '확인',
    })
  }

  const showSuccess = (message: string, title = '성공') => {
    return Swal.fire({
      icon: 'success',
      title,
      text: message,
      confirmButtonText: '확인',
    })
  }

  const showInfo = (message: string, title = '알림') => {
    return Swal.fire({
      icon: 'info',
      title,
      text: message,
      confirmButtonText: '확인',
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
      confirmButtonColor: '#dc3545',
    }).then((result) => result.isConfirmed)
  }

  const toastSuccess = (message: string) => {
    return Toast.fire({
      icon: 'success',
      title: message,
    })
  }

  const toastError = (message: string) => {
    return Toast.fire({
      icon: 'error',
      title: message,
    })
  }

  const toastInfo = (message: string) => {
    return Toast.fire({
      icon: 'info',
      title: message,
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
    toastInfo,
  }
}
