const sweetAlTimer = 1500;

const attachmentValidation = Object.freeze({
  maxFileSizeBytes: 50 * 1024 * 1024,
  maxFileSizeLabel: '50MB',
  tooLargeMessage(filename) {
    return `${filename} 파일은 ${this.maxFileSizeLabel}를 초과합니다.`;
  },
  blockedExtensionMessage(filename) {
    return `${filename} 파일은 업로드할 수 없는 확장자입니다.`;
  }
});

window.AttachmentValidation = attachmentValidation;

const isEndsWithLastConsonantLetter = function (text) {
  const strGa = 44032; // 가
  const strHih = 55203; // 힣
  const lastStrCode = text.charCodeAt(text.length - 1);

  if (lastStrCode < strGa || lastStrCode > strHih) {
    return false; // if it's not Korean, return false
  }
  return ((lastStrCode - strGa) % 28 === 0)
}

const roChecker = function (text) {
  return isEndsWithLastConsonantLetter(text) ? '로' : '으로';
}
const rulChecker = function (text) {
  return isEndsWithLastConsonantLetter(text) ? '를' : '을';
}

function toLocalISOString(date) {
  const offsetInMs = date.getTimezoneOffset() * 60000;
  const localDate = new Date(date - offsetInMs);
  return localDate.toISOString().slice(0, -1);
}

const vueFilters = {
  formatDate(value) {
    if (value && value.length > 10) {
      return value.substring(0, 10);
    }
    return value;
  },

  formatDateTime(value) {
    if (value && value.length > 19) {
      return value.substring(0, 19);
    }
    return value;
  },

  fromNow(value) {
    if (typeof dayjs !== "undefined") {
      return dayjs(value).fromNow();
    }
    return value;
  },
};

document.addEventListener("DOMContentLoaded", function () {
  if (typeof Vue !== "undefined") {
    Object.keys(vueFilters).forEach((key) => {
      Vue.filter(key, vueFilters[key]);
    });
  }
});

formatDate = function (year, month, day) {
  month = month < 10 ? '0' + month : month;
  day = day < 10 ? '0' + day : day;
  return year + '-' + month + '-' + day;
}

const schedule_content_max_length = 30;

function isValidContent(content) {
  if (!content) {
    Swal.fire({
      icon: 'error',
      title: '내용을 입력해주세요.',
      showConfirmButton: false,
      timer: sweetAlTimer
    });
    return false;
  }
  if (content.length > schedule_content_max_length) {
    Swal.fire({
      icon: 'error',
      title: schedule_content_max_length + '자 이내로 입력해주세요.',
      showConfirmButton: false,
      timer: sweetAlTimer
    });
    return false;
  }
  return true;
}
