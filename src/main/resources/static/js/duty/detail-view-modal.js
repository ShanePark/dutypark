const ATTACHMENT_CONTEXT_TYPE = 'SCHEDULE';

const attachmentValidationConfig = window.AttachmentValidation || {
  maxFileSizeBytes: 50 * 1024 * 1024,
  maxFileSizeLabel: '50MB',
  blockedExtensions: [],
  tooLargeMessage(filename) {
    return `${filename} 파일은 업로드할 수 없습니다.`;
  },
  blockedExtensionMessage(filename) {
    return `${filename} 파일은 업로드할 수 없습니다.`;
  }
};

const normalizeAttachmentDto = (dto) => ({
  id: dto.id,
  name: dto.originalFilename,
  contentType: dto.contentType,
  size: dto.size,
  thumbnailUrl: dto.thumbnailUrl,
  downloadUrl: `/api/attachments/${dto.id}/download`,
  isImage: dto.contentType ? dto.contentType.startsWith('image/') : false,
  hasThumbnail: dto.hasThumbnail,
  orderIndex: dto.orderIndex,
  createdAt: dto.createdAt,
  createdBy: dto.createdBy,
});

const getFileExtension = (filename) => {
  if (!filename || filename.indexOf('.') === -1) {
    return '';
  }
  return filename.split('.').pop().toLowerCase();
};

const validateAttachmentFile = (file) => {
  if (!file) {
    return {
      valid: false,
      message: '업로드할 파일을 찾지 못했습니다.'
    };
  }
  if (file.size > attachmentValidationConfig.maxFileSizeBytes) {
    return {
      valid: false,
      message: attachmentValidationConfig.tooLargeMessage(file.name)
    };
  }
  const extension = getFileExtension(file.name);
  if (extension && attachmentValidationConfig.blockedExtensions.includes(extension)) {
    return {
      valid: false,
      message: attachmentValidationConfig.blockedExtensionMessage(file.name)
    };
  }
  return {valid: true};
};

const showAttachmentAlert = (message) => {
  Swal.fire({
    icon: 'error',
    title: message,
    showConfirmButton: false,
    timer: sweetAlTimer
  });
};

const buildUploadProgressPayload = (event) => {
  if (!event || !event.lengthComputable) {
    return {
      bytesUploaded: event ? event.loaded : 0,
      bytesTotal: event ? event.total : 0,
      progress: 0
    };
  }
  return {
    bytesUploaded: event.loaded,
    bytesTotal: event.total,
    progress: event.total > 0 ? event.loaded / event.total : 0
  };
};

const handleAttachmentResponseError = async (response, fallbackMessage, options = {}) => {
  const {fileName} = options;
  let message = fallbackMessage;
  if (response) {
    if (response.status === 413 && fileName) {
      message = attachmentValidationConfig.tooLargeMessage(fileName);
    } else {
      let body = null;
      try {
        body = await response.clone().json();
      } catch (e) {
        body = null;
      }
      if (response.status === 400 && body?.code === 'ATTACHMENT_EXTENSION_BLOCKED' && fileName) {
        message = attachmentValidationConfig.blockedExtensionMessage(fileName);
      } else if (body?.message) {
        message = body.message;
      }
    }
  }
  showAttachmentAlert(message);
  throw new Error(message);
};

const handleAttachmentXhrError = (xhr, file) => {
  const fileName = file?.name;
  if (xhr.status === 0) {
    showAttachmentAlert('네트워크 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
    return new Error('Network error during attachment upload');
  }
  if (xhr.status === 413 && fileName) {
    const message = attachmentValidationConfig.tooLargeMessage(fileName);
    showAttachmentAlert(message);
    return new Error(message);
  }
  if (xhr.status === 400 && xhr.response?.code === 'ATTACHMENT_EXTENSION_BLOCKED' && fileName) {
    const message = attachmentValidationConfig.blockedExtensionMessage(fileName);
    showAttachmentAlert(message);
    return new Error(message);
  }
  const message = xhr.response?.message || '파일 업로드에 실패했습니다.';
  showAttachmentAlert(message);
  return new Error(message);
};

const detailViewMethods = {
  scheduleCreateMode() {
    this.resetCreateSchedule();
    this.isCreateScheduleMode = true;
  }
  ,
  cancelCreateSchedule() {
    this.isCreateScheduleMode = false;
  }
  ,
  saveSchedule() {
    const app = this;
    if (!isValidContent(app.createSchedule.content)) {
      return;
    }
    if (!app.isValidDateTime(app.createSchedule.startDateTime, app.createSchedule.endDateTime)) {
      return;
    }
    const addArea = $('#schedule-create-or-edit');
    addArea.waitMe();
    $.ajax({
      url: '/api/schedules',
      type: 'POST',
      data: JSON.stringify({
        id: app.createSchedule.id,
        memberId: app.memberId,
        content: app.createSchedule.content,
        description: app.createSchedule.description,
        startDateTime: toLocalISOString(new Date(app.createSchedule.startDateTime)),
        endDateTime: toLocalISOString(new Date(app.createSchedule.endDateTime)),
        visibility: app.createSchedule.visibility,
      }),
      contentType: 'application/json',
      success: (data) => {
        app.loadSchedule();
        app.isCreateScheduleMode = false;
      },
      error: (data) => {
        Swal.fire({
          icon: 'error',
          title: '저장에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
      }, complete: () => {
        addArea.waitMe('hide');
      }
    })
  }
  ,
  scheduleEditMode(schedule) {
    this.scheduleCreateMode();
    this.createSchedule.id = schedule.id;
    this.createSchedule.content = schedule.content;
    this.createSchedule.description = schedule.description;
    this.createSchedule.startDateTime = schedule.startDateTime;
    this.createSchedule.startDate = schedule.startDateTime.split('T')[0];
    this.createSchedule.startTime = schedule.startDateTime.split('T')[1];
    this.createSchedule.endDateTime = schedule.endDateTime;
    this.createSchedule.visibility = schedule.visibility;
  }
  ,
  swapSchedule(schedule1, schedule2) {
    const app = this;
    $('#detail-view-modal .schedules').waitMe();
    if (!schedule1 || !schedule2 || schedule1 === schedule2) {
      return;
    }
    fetch(`/api/schedules/${schedule1.id}/position?id2=${schedule2.id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json'
      },
    }).then((response) => {
      $('.schedules').waitMe('hide');
      if (response.ok) {
        app.loadSchedule();
      } else {
        Swal.fire({
          icon: 'error',
          title: '순서 변경에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
      }
    });
  }
  ,
  deleteSchedule(schedule) {
    const app = this;
    Swal.fire({
      title: '일정을 삭제하시겠습니까?',
      html: `다음의 일정을 삭제합니다.<br/>[${schedule.content}]<br/> 삭제된 일정은 복구할 수 없습니다.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#d33',
      cancelButtonColor: '#999',
      confirmButtonText: '삭제',
      cancelButtonText: '취소',
    }).then((result) => {
      if (result.isConfirmed) {
        const deleteArea = $('#schedule-' + schedule.id);
        deleteArea.waitMe();
        $.ajax({
          url: '/api/schedules/' + schedule.id,
          type: 'DELETE',
          success: (data) => {
            app.loadSchedule();
          },
          error: (data) => {
            Swal.fire({
              icon: 'error',
              title: '삭제에 실패했습니다.',
              showConfirmButton: false,
              timer: sweetAlTimer
            });
          }, complete: () => {
            deleteArea.waitMe('hide');
          }
        })
      }
    })
  }
  ,
  untagSelf(schedule) {
    const app = this;
    if (!app.isMyCalendar) {
      return;
    }
    const scheduleId = schedule.id;
    const scheduleElement = document.getElementById('schedule-' + scheduleId);
    const scheduleBy = scheduleElement.querySelector('.schedule-tags')
        .querySelector('.schedule-tag.tagged-true').innerText;

    Swal.fire({
      title: '정말로 태그를 제거하시겠습니까?',
      html: `태그된 아래의 일정을 제거합니다.<br/>[${schedule.content}] by${scheduleBy}<br/> 태그를 다시 복구하려면 해당 사용자에게 요청해야합니다.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#d33',
      cancelButtonColor: '#999',
      confirmButtonText: '제거',
      cancelButtonText: '취소',
    }).then((result) => {
      if (result.isConfirmed) {
        fetch(`/api/schedules/${scheduleId}/tags`, {
          method: 'DELETE',
        }).then(response => {
          if (!response.ok) {
            Swal.fire({
              icon: 'error',
              title: '태그 제거에 실패했습니다.',
              showConfirmButton: false,
              timer: sweetAlTimer
            });
            return;
          }
          app.loadSchedule();
        });
      }
    });
  }
  ,
  isDutyType(duty, dutyType) {
    if (duty?.dutyType) {
      return dutyType.name === duty.dutyType
    }
    return !dutyType.id
  }
  ,
  changeDutyTypeWithPopup(duty, type) {
    if (duty?.dutyType && duty.dutyType === type.name) {
      return;
    }
    if (!duty?.dutyType && !type.id) {
      return;
    }

    this.changeDutyType(duty, type);
    Swal.fire({
      icon: 'success',
      title: '변경되었습니다.',
      showConfirmButton: false,
      timer: sweetAlTimer / 3,
    });
  }
  ,
  validateAttachment(file) {
    const validation = validateAttachmentFile(file);
    if (!validation.valid && validation.message) {
      showAttachmentAlert(validation.message);
    }
    return validation;
  }
  ,
  normalizeAttachment(dto) {
    return normalizeAttachmentDto(dto);
  }
  ,
  async createAttachmentSession(targetContextId = null) {
    const payload = {
      contextType: ATTACHMENT_CONTEXT_TYPE,
    };
    if (targetContextId) {
      payload.targetContextId = targetContextId;
    }
    const response = await fetch('/api/attachments/sessions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      await handleAttachmentResponseError(response, '파일 업로드 세션 생성에 실패했습니다.');
    }
    return response.json();
  }
  ,
  uploadAttachment(file, sessionId, options = {}) {
    const {onProgress} = options;
    const validation = validateAttachmentFile(file);
    if (!validation.valid) {
      return Promise.reject(new Error(validation.message || 'Invalid attachment file'));
    }
    if (!sessionId) {
      const message = '파일 업로드 세션이 없습니다. 다시 시도해주세요.';
      showAttachmentAlert(message);
      return Promise.reject(new Error(message));
    }
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/api/attachments');
      xhr.responseType = 'json';
      if (typeof onProgress === 'function') {
        xhr.upload.addEventListener('progress', (event) => {
          onProgress(buildUploadProgressPayload(event));
        });
      }
      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300 && xhr.response) {
          resolve(normalizeAttachmentDto(xhr.response));
          return;
        }
        reject(handleAttachmentXhrError(xhr, file));
      });
      xhr.addEventListener('error', () => {
        reject(handleAttachmentXhrError(xhr, file));
      });
      xhr.addEventListener('abort', () => {
        reject(new Error('Attachment upload aborted'));
      });
      const formData = new FormData();
      formData.append('sessionId', sessionId);
      formData.append('file', file);
      xhr.send(formData);
    });
  }
  ,
  async finalizeAttachmentSession(sessionId, contextId, orderedAttachmentIds = []) {
    const response = await fetch(`/api/attachments/sessions/${sessionId}/finalize`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        contextId: contextId,
        orderedAttachmentIds: orderedAttachmentIds
      })
    });
    if (!response.ok) {
      await handleAttachmentResponseError(response, '첨부파일을 저장하는 데 실패했습니다.');
    }
  }
  ,
  async listAttachments(contextId) {
    const response = await fetch(`/api/attachments?contextType=${ATTACHMENT_CONTEXT_TYPE}&contextId=${contextId}`, {
      method: 'GET'
    });
    if (!response.ok) {
      await handleAttachmentResponseError(response, '첨부파일 목록을 불러오지 못했습니다.');
    }
    const attachments = await response.json();
    return attachments.map(normalizeAttachmentDto);
  }
  ,
  async deleteAttachment(attachmentId) {
    const response = await fetch(`/api/attachments/${attachmentId}`, {
      method: 'DELETE'
    });
    if (!response.ok) {
      await handleAttachmentResponseError(response, '첨부파일 삭제에 실패했습니다.');
    }
  }
  ,
  async reorderAttachments(contextId, orderedAttachmentIds) {
    const response = await fetch('/api/attachments/reorder', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        contextType: ATTACHMENT_CONTEXT_TYPE,
        contextId: contextId,
        orderedAttachmentIds: orderedAttachmentIds
      })
    });
    if (!response.ok) {
      await handleAttachmentResponseError(response, '첨부파일 순서를 저장하는 데 실패했습니다.');
    }
  }
  ,
  replaceLineBreaks(text) {
    if (text) {
      return text.replace(/\n/g, '<br>');
    }
    return '';
  }
  ,
}
