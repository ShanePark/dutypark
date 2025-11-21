const sweetAlTimer = 1500;

// Tailwind Modal Helper Functions
const TwModal = {
  show(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
      modal.classList.remove('hidden');
      modal.classList.add('flex');
      document.body.classList.add('overflow-hidden');
      // Trigger shown event for compatibility
      modal.dispatchEvent(new CustomEvent('shown.tw.modal'));
    }
  },
  hide(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
      modal.classList.add('hidden');
      modal.classList.remove('flex');
      document.body.classList.remove('overflow-hidden');
      // Trigger hidden event for compatibility
      modal.dispatchEvent(new CustomEvent('hidden.tw.modal'));
    }
  },
  toggle(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
      if (modal.classList.contains('hidden')) {
        TwModal.show(modalId);
      } else {
        TwModal.hide(modalId);
      }
    }
  }
};

// jQuery-like modal method for backwards compatibility
if (typeof jQuery !== 'undefined') {
  jQuery.fn.modal = function(action) {
    return this.each(function() {
      const modalId = this.id;
      if (action === 'show') {
        TwModal.show(modalId);
      } else if (action === 'hide') {
        TwModal.hide(modalId);
      } else if (action === 'toggle') {
        TwModal.toggle(modalId);
      }
    });
  };
}

// Tailwind Dropdown Helper Functions
const TwDropdown = {
  show(menuElement) {
    if (menuElement) {
      menuElement.classList.add('show');
      menuElement.classList.remove('hidden');
    }
  },
  hide(menuElement) {
    if (menuElement) {
      menuElement.classList.remove('show');
      menuElement.classList.add('hidden');
    }
  },
  toggle(menuElement) {
    if (menuElement) {
      if (menuElement.classList.contains('show')) {
        TwDropdown.hide(menuElement);
      } else {
        TwDropdown.show(menuElement);
      }
    }
  }
};

// Auto-initialize modal and dropdown handlers
document.addEventListener('DOMContentLoaded', function() {
  // Modal close button handler
  document.querySelectorAll('[data-tw-dismiss="modal"]').forEach(btn => {
    btn.addEventListener('click', function() {
      const modal = this.closest('[data-tw-modal]');
      if (modal) {
        TwModal.hide(modal.id);
      }
    });
  });

  // Modal backdrop click handler
  document.querySelectorAll('[data-tw-modal]').forEach(modal => {
    modal.addEventListener('click', function(e) {
      if (e.target === this) {
        TwModal.hide(this.id);
      }
    });
  });

  // Dropdown toggle handler
  document.querySelectorAll('[data-tw-toggle="dropdown"]').forEach(btn => {
    btn.addEventListener('click', function(e) {
      e.stopPropagation();
      const menu = this.nextElementSibling;
      if (menu && menu.classList.contains('dropdown-menu')) {
        // Close other dropdowns first
        document.querySelectorAll('.dropdown-menu.show').forEach(m => {
          if (m !== menu) TwDropdown.hide(m);
        });
        TwDropdown.toggle(menu);
      }
    });
  });

  // Close dropdowns when clicking outside
  document.addEventListener('click', function(e) {
    if (!e.target.closest('.dropdown')) {
      document.querySelectorAll('.dropdown-menu.show').forEach(menu => {
        TwDropdown.hide(menu);
      });
    }
  });

  // ESC key handler for modals and dropdowns
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
      // Close modals
      document.querySelectorAll('[data-tw-modal]:not(.hidden)').forEach(modal => {
        TwModal.hide(modal.id);
      });
      // Close dropdowns
      document.querySelectorAll('.dropdown-menu.show').forEach(menu => {
        TwDropdown.hide(menu);
      });
    }
  });
});

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
