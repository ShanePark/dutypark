const sweetAlTimer = 1500;

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
  }
};

document.addEventListener("DOMContentLoaded", function () {
  if (typeof Vue !== "undefined") {
    Object.keys(vueFilters).forEach((key) => {
      Vue.filter(key, vueFilters[key]);
    });
  }
});
