const ATTACHMENT_CONTEXT_TYPE = 'SCHEDULE';

const attachmentValidationConfig = window.AttachmentValidation || {
  maxFileSizeBytes: 50 * 1024 * 1024,
  maxFileSizeLabel: '50MB',
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

const ATTACHMENT_ICON_BY_EXTENSION = {
  pdf: 'bi-file-earmark-pdf',
  doc: 'bi-file-earmark-word',
  docx: 'bi-file-earmark-word',
  docm: 'bi-file-earmark-word',
  dot: 'bi-file-earmark-word',
  dotx: 'bi-file-earmark-word',
  xls: 'bi-file-earmark-spreadsheet',
  xlsx: 'bi-file-earmark-spreadsheet',
  xlsm: 'bi-file-earmark-spreadsheet',
  xlsb: 'bi-file-earmark-spreadsheet',
  csv: 'bi-file-earmark-spreadsheet',
  tsv: 'bi-file-earmark-spreadsheet',
  ppt: 'bi-file-earmark-ppt',
  pptx: 'bi-file-earmark-ppt',
  pptm: 'bi-file-earmark-ppt',
  key: 'bi-file-earmark-ppt',
  txt: 'bi-file-earmark-text',
  md: 'bi-file-earmark-text',
  rtf: 'bi-file-earmark-text',
  log: 'bi-file-earmark-text',
  ics: 'bi-file-earmark-text',
  json: 'bi-file-earmark-code',
  yml: 'bi-file-earmark-code',
  yaml: 'bi-file-earmark-code',
  html: 'bi-file-earmark-code',
  htm: 'bi-file-earmark-code',
  xml: 'bi-file-earmark-code',
  js: 'bi-file-earmark-code',
  jsx: 'bi-file-earmark-code',
  ts: 'bi-file-earmark-code',
  tsx: 'bi-file-earmark-code',
  java: 'bi-file-earmark-code',
  kt: 'bi-file-earmark-code',
  kts: 'bi-file-earmark-code',
  py: 'bi-file-earmark-code',
  php: 'bi-file-earmark-code',
  rb: 'bi-file-earmark-code',
  go: 'bi-file-earmark-code',
  rs: 'bi-file-earmark-code',
  swift: 'bi-file-earmark-code',
  sql: 'bi-file-earmark-code',
  sh: 'bi-file-earmark-code',
  bat: 'bi-file-earmark-code',
  ps1: 'bi-file-earmark-code',
  c: 'bi-file-earmark-code',
  cpp: 'bi-file-earmark-code',
  cs: 'bi-file-earmark-code',
  mp3: 'bi-file-earmark-music',
  wav: 'bi-file-earmark-music',
  flac: 'bi-file-earmark-music',
  ogg: 'bi-file-earmark-music',
  aac: 'bi-file-earmark-music',
  m4a: 'bi-file-earmark-music',
  wma: 'bi-file-earmark-music',
  mp4: 'bi-file-earmark-play',
  m4v: 'bi-file-earmark-play',
  mov: 'bi-file-earmark-play',
  avi: 'bi-file-earmark-play',
  mkv: 'bi-file-earmark-play',
  webm: 'bi-file-earmark-play',
  wmv: 'bi-file-earmark-play',
  mpg: 'bi-file-earmark-play',
  mpeg: 'bi-file-earmark-play',
  gif: 'bi-file-earmark-image',
  jpg: 'bi-file-earmark-image',
  jpeg: 'bi-file-earmark-image',
  png: 'bi-file-earmark-image',
  bmp: 'bi-file-earmark-image',
  svg: 'bi-file-earmark-image',
  webp: 'bi-file-earmark-image',
  heic: 'bi-file-earmark-image',
  heif: 'bi-file-earmark-image',
  psd: 'bi-file-earmark-image',
  ai: 'bi-file-earmark-image',
  eps: 'bi-file-earmark-image',
  zip: 'bi-file-earmark-zip',
  rar: 'bi-file-earmark-zip',
  '7z': 'bi-file-earmark-zip',
  gz: 'bi-file-earmark-zip',
  tgz: 'bi-file-earmark-zip',
  tar: 'bi-file-earmark-zip',
  bz2: 'bi-file-earmark-zip',
  xz: 'bi-file-earmark-zip',
  iso: 'bi-file-earmark-binary',
  dmg: 'bi-file-earmark-binary',
  exe: 'bi-file-earmark-binary',
  dll: 'bi-file-earmark-binary',
  bin: 'bi-file-earmark-binary',
  apk: 'bi-file-earmark-binary',
  ipa: 'bi-file-earmark-binary',
};

const ATTACHMENT_ICON_BY_CONTENT_TYPE = {
  'application/pdf': 'bi-file-earmark-pdf',
  'application/msword': 'bi-file-earmark-word',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'bi-file-earmark-word',
  'application/vnd.ms-excel': 'bi-file-earmark-spreadsheet',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'bi-file-earmark-spreadsheet',
  'application/vnd.ms-powerpoint': 'bi-file-earmark-ppt',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'bi-file-earmark-ppt',
  'text/plain': 'bi-file-earmark-text',
  'text/markdown': 'bi-file-earmark-text',
  'text/csv': 'bi-file-earmark-spreadsheet',
  'application/json': 'bi-file-earmark-code',
  'application/xml': 'bi-file-earmark-code',
  'text/xml': 'bi-file-earmark-code',
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

const createAttachmentSession = async (targetContextId = null) => {
  const response = await fetch('/api/attachments/sessions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      contextType: ATTACHMENT_CONTEXT_TYPE,
      targetContextId: targetContextId
    })
  });
  if (!response.ok) {
    await handleAttachmentResponseError(response, '업로드 세션 생성에 실패했습니다.');
  }
  return await response.json();
};

const finalizeAttachmentSession = async (sessionId, contextId, orderedAttachmentIds = []) => {
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
    await handleAttachmentResponseError(response, '첨부파일 저장에 실패했습니다.');
  }
};

const deleteAttachment = async (attachmentId) => {
  const response = await fetch(`/api/attachments/${attachmentId}`, {
    method: 'DELETE'
  });
  if (!response.ok) {
    await handleAttachmentResponseError(response, '첨부파일 삭제에 실패했습니다.');
  }
};

const detailViewMethods = {
  async scheduleCreateMode() {
    this.resetCreateSchedule();
    this.isCreateScheduleMode = true;
    await this.$nextTick();
    await this.initializeAttachmentUploader();
  }
  ,
  async cancelCreateSchedule() {
    if (this.createSchedule.attachmentSessionId) {
      try {
        await fetch(`/api/attachments/sessions/${this.createSchedule.attachmentSessionId}`, {
          method: 'DELETE'
        });
      } catch (error) {
        console.warn('Failed to cleanup attachment session:', error);
      }
    }
    this.cleanupAttachmentUploader();
    this.isCreateScheduleMode = false;
  }
  ,
  async saveSchedule() {
    const app = this;
    if (app.isAttachmentUploading) {
      Swal.fire({
        icon: 'info',
        title: '파일 업로드가 진행 중입니다.',
        text: '업로드가 완료될 때까지 기다려주세요.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      return;
    }
    if (!isValidContent(app.createSchedule.content)) {
      return;
    }
    if (!app.isValidDateTime(app.createSchedule.startDateTime, app.createSchedule.endDateTime)) {
      return;
    }
    const addArea = $('#schedule-create-or-edit');
    addArea.waitMe();

    try {
      const orderedAttachmentIds = app.createSchedule.uploadedAttachments.map(a => a.id);

      const response = await fetch('/api/schedules', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          id: app.createSchedule.id,
          memberId: app.memberId,
          content: app.createSchedule.content,
          description: app.createSchedule.description,
          startDateTime: toLocalISOString(new Date(app.createSchedule.startDateTime)),
          endDateTime: toLocalISOString(new Date(app.createSchedule.endDateTime)),
          visibility: app.createSchedule.visibility,
          attachmentSessionId: app.createSchedule.attachmentSessionId,
          orderedAttachmentIds: orderedAttachmentIds,
        })
      });

      if (!response.ok) {
        throw new Error('Schedule save failed');
      }

      await response.json();

      app.cleanupAttachmentUploader();
      app.loadSchedule();
      app.isCreateScheduleMode = false;
    } catch (error) {
      console.error('Failed to save schedule:', error);
      Swal.fire({
        icon: 'error',
        title: '저장에 실패했습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
    } finally {
      addArea.waitMe('hide');
    }
  }
  ,
  async scheduleEditMode(schedule) {
    await this.scheduleCreateMode();
    this.createSchedule.id = schedule.id;
    this.createSchedule.content = schedule.content;
    this.createSchedule.description = schedule.description;
    this.createSchedule.startDateTime = schedule.startDateTime;
    this.createSchedule.startDate = schedule.startDateTime.split('T')[0];
    this.createSchedule.startTime = schedule.startDateTime.split('T')[1];
    this.createSchedule.endDateTime = schedule.endDateTime;
    this.createSchedule.visibility = schedule.visibility;

    if (schedule.attachments && schedule.attachments.length > 0) {
      this.createSchedule.uploadedAttachments = schedule.attachments.map(att => ({
        id: att.id,
        name: att.originalFilename,
        contentType: att.contentType,
        size: att.size,
        thumbnailUrl: att.thumbnailUrl,
        downloadUrl: `/api/attachments/${att.id}/download`,
        isImage: att.contentType ? att.contentType.startsWith('image/') : false,
        hasThumbnail: att.hasThumbnail,
        orderIndex: att.orderIndex,
        createdAt: att.createdAt,
        createdBy: att.createdBy,
      }));
    }
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
  async initializeAttachmentUploader() {
    const app = this;

    if (app.uppyInstance) {
      try {
        app.uppyInstance.cancelAll();
      } catch (e) {
        console.warn('Error cleaning up previous Uppy instance:', e);
      }
      app.uppyInstance = null;
    }

    if (app.fileInputListener) {
      const fileInput = document.getElementById('schedule-attachment-input');
      if (fileInput) {
        fileInput.removeEventListener('change', app.fileInputListener);
      }
      app.fileInputListener = null;
    }

    try {
      const {Uppy, XHRUpload} = await import('/lib/uppy-5.1.7/uppy.min.mjs');

      app.uppyInstance = new Uppy({
        restrictions: {
          maxFileSize: attachmentValidationConfig.maxFileSizeBytes,
          allowedFileTypes: null,
        },
        autoProceed: true,
      })
        .use(XHRUpload, {
          endpoint: '/api/attachments',
          fieldName: 'file',
          formData: true,
          bundle: false,
          headers: {},
          getResponseData(responseText, response) {
            const text = typeof responseText === 'string' ? responseText : (responseText.responseText || responseText.response);
            console.log('Server response text:', text);
            try {
              return JSON.parse(text);
            } catch (e) {
              console.error('Failed to parse JSON response:', text);
              throw new Error(`Invalid JSON response: ${text ? text.substring(0, 100) : 'empty'}`);
            }
          },
        });

      const ATTACHMENT_SESSION_ERROR = 'ATTACHMENT_SESSION_CREATION_FAILED';

      const ensureAttachmentSession = async () => {
        if (app.createSchedule.attachmentSessionId) {
          return app.createSchedule.attachmentSessionId;
        }
        if (!app.createSchedule.sessionCreationPromise) {
          app.createSchedule.sessionCreationPromise = (async () => {
            const sessionResponse = await createAttachmentSession(null);
            app.createSchedule.attachmentSessionId = sessionResponse.sessionId;
            return sessionResponse.sessionId;
          })();
        }
        try {
          const sessionId = await app.createSchedule.sessionCreationPromise;
          app.createSchedule.sessionCreationPromise = null;
          return sessionId;
        } catch (error) {
          app.createSchedule.sessionCreationPromise = null;
          throw error;
        }
      };

      app.uppyInstance.on('file-added', (file) => {
        const fileData = file?.data;
        const validation = validateAttachmentFile(fileData);
        if (!validation.valid) {
          app.uppyInstance.removeFile(file.id);
          showAttachmentAlert(validation.message);
          return;
        }

        const mimeType = fileData?.type || '';
        const isImage = mimeType.startsWith('image/');
        const now = Date.now();
        const wasIdle = Object.keys(app.createSchedule.attachmentUploadMeta || {}).length === 0;
        const tempAttachment = {
          id: file.id,
          name: fileData?.name,
          contentType: mimeType,
          size: fileData?.size || 0,
          isImage: isImage,
          previewUrl: isImage ? URL.createObjectURL(fileData) : null,
        };
        app.createSchedule.uploadedAttachments.push(tempAttachment);
        app.$set(app.createSchedule.attachmentProgress, file.id, 0);
        app.$set(app.createSchedule.attachmentUploadMeta, file.id, {
          bytesUploaded: 0,
          bytesTotal: fileData?.size || 0,
          startedAt: now,
          lastUpdatedAt: now,
        });
        if (wasIdle) {
          app.startAttachmentUploadTicker();
        }
      });

      app.uppyInstance.addPreProcessor(async (fileIDs) => {
        if (!fileIDs || fileIDs.length === 0) {
          return;
        }

        let sessionId;
        try {
          sessionId = await ensureAttachmentSession();
        } catch (error) {
          console.error('Failed to ensure attachment session before upload:', error);
          showAttachmentAlert('파일 업로드 세션 생성에 실패했습니다.');
          fileIDs.forEach((fileId) => {
            const file = app.uppyInstance.getFile(fileId);
            if (file) {
              app.uppyInstance.removeFile(fileId);
            }
            app.$delete(app.createSchedule.attachmentProgress, fileId);
            if (app.createSchedule.attachmentUploadMeta && app.createSchedule.attachmentUploadMeta[fileId]) {
              app.$delete(app.createSchedule.attachmentUploadMeta, fileId);
            }
            const index = app.createSchedule.uploadedAttachments.findIndex(a => a.id === fileId);
            if (index !== -1) {
              const attachment = app.createSchedule.uploadedAttachments[index];
              if (attachment.previewUrl) {
                URL.revokeObjectURL(attachment.previewUrl);
              }
              app.createSchedule.uploadedAttachments.splice(index, 1);
            }
          });
          if (Object.keys(app.createSchedule.attachmentUploadMeta || {}).length === 0) {
            app.stopAttachmentUploadTicker();
          }
          throw new Error(ATTACHMENT_SESSION_ERROR);
        }

        fileIDs.forEach((fileId) => {
          const file = app.uppyInstance.getFile(fileId);
          if (!file) {
            return;
          }
          app.uppyInstance.setFileMeta(fileId, {
            ...file.meta,
            sessionId: String(sessionId),
          });
        });
      });

      app.uppyInstance.on('upload-progress', (file, progress) => {
        const bytesUploaded = progress.bytesUploaded || 0;
        const totalFromEvent = progress.bytesTotal;
        const fallbackTotal = file?.data?.size || 0;
        const bytesTotal = typeof totalFromEvent === 'number' && totalFromEvent > 0 ? totalFromEvent : fallbackTotal;
        const percentage = bytesTotal > 0 ? Math.round((bytesUploaded / bytesTotal) * 100) : 0;
        app.$set(app.createSchedule.attachmentProgress, file.id, percentage);
        const meta = app.createSchedule.attachmentUploadMeta ? app.createSchedule.attachmentUploadMeta[file.id] : null;
        if (meta) {
          meta.bytesUploaded = bytesUploaded;
          meta.bytesTotal = bytesTotal;
          meta.lastUpdatedAt = Date.now();
        }
      });

      app.uppyInstance.on('upload-success', (file, response) => {
        const attachmentDto = response.body;
        const normalized = normalizeAttachmentDto(attachmentDto);
        const fileType = file?.data?.type || '';

        const index = app.createSchedule.uploadedAttachments.findIndex(a => a.id === file.id);
        if (index !== -1) {
          const oldPreviewUrl = app.createSchedule.uploadedAttachments[index].previewUrl;
          if (fileType.startsWith('image/') && !normalized.previewUrl) {
            normalized.previewUrl = oldPreviewUrl;
          }
          app.$set(app.createSchedule.uploadedAttachments, index, normalized);
        }
        app.$delete(app.createSchedule.attachmentProgress, file.id);
        if (app.createSchedule.attachmentUploadMeta && app.createSchedule.attachmentUploadMeta[file.id]) {
          app.$delete(app.createSchedule.attachmentUploadMeta, file.id);
        }
        if (Object.keys(app.createSchedule.attachmentUploadMeta || {}).length === 0) {
          app.stopAttachmentUploadTicker();
        }
      });

      app.uppyInstance.on('upload-error', (file, error, response) => {
        if (error?.message === ATTACHMENT_SESSION_ERROR) {
          return;
        }
        console.error('Upload error:', error, response);
        const index = app.createSchedule.uploadedAttachments.findIndex(a => a.id === file.id);
        if (index !== -1) {
          const attachment = app.createSchedule.uploadedAttachments[index];
          if (attachment.previewUrl) {
            URL.revokeObjectURL(attachment.previewUrl);
          }
          app.createSchedule.uploadedAttachments.splice(index, 1);
        }
        app.$delete(app.createSchedule.attachmentProgress, file.id);
        if (app.createSchedule.attachmentUploadMeta && app.createSchedule.attachmentUploadMeta[file.id]) {
          app.$delete(app.createSchedule.attachmentUploadMeta, file.id);
        }
        if (Object.keys(app.createSchedule.attachmentUploadMeta || {}).length === 0) {
          app.stopAttachmentUploadTicker();
        }
        if (response && response.body) {
          handleAttachmentXhrError({status: response.status, response: response.body}, file?.data);
        } else {
          showAttachmentAlert('파일 업로드에 실패했습니다.');
        }
      });

      app.fileInputListener = (event) => {
        const files = Array.from(event.target.files);
        files.forEach(file => {
          try {
            app.uppyInstance.addFile({
              name: file.name,
              type: file.type,
              data: file,
            });
          } catch (err) {
            console.error('Failed to add file:', err);
            showAttachmentAlert(`파일 추가에 실패했습니다: ${file.name}`);
          }
        });
        event.target.value = '';
      };

      await app.$nextTick();
      const fileInput = document.getElementById('schedule-attachment-input');
      if (fileInput) {
        fileInput.addEventListener('change', app.fileInputListener);
      }

    } catch (error) {
      console.error('Failed to initialize attachment uploader:', error);
      showAttachmentAlert('첨부파일 업로드 기능을 초기화하지 못했습니다.');
    }
  }
  ,
  removeAttachment(attachmentId) {
    const app = this;
    const index = app.createSchedule.uploadedAttachments.findIndex(a => a.id === attachmentId);
    if (index === -1) return;

    const attachment = app.createSchedule.uploadedAttachments[index];
    app.createSchedule.uploadedAttachments.splice(index, 1);

    if (attachment.previewUrl) {
      URL.revokeObjectURL(attachment.previewUrl);
    }
    if (app.createSchedule.attachmentProgress && app.createSchedule.attachmentProgress[attachmentId] !== undefined) {
      app.$delete(app.createSchedule.attachmentProgress, attachmentId);
    }
    if (app.createSchedule.attachmentUploadMeta && app.createSchedule.attachmentUploadMeta[attachmentId]) {
      app.$delete(app.createSchedule.attachmentUploadMeta, attachmentId);
    }
    if (Object.keys(app.createSchedule.attachmentUploadMeta || {}).length === 0) {
      app.stopAttachmentUploadTicker();
    }
    if (app.uppyInstance) {
      const uploadingFile = app.uppyInstance.getFile(attachmentId);
      if (uploadingFile) {
        try {
          app.uppyInstance.removeFile(attachmentId);
        } catch (error) {
          console.warn('Failed to remove file from uploader:', error);
        }
      }
    }
  }
  ,
  cleanupAttachmentUploader() {
    const app = this;

    if (app.uppyInstance) {
      try {
        app.uppyInstance.cancelAll();
      } catch (e) {
        console.warn('Error cleaning up Uppy instance:', e);
      }
      app.uppyInstance = null;
    }

    if (app.fileInputListener) {
      const fileInput = document.getElementById('schedule-attachment-input');
      if (fileInput) {
        fileInput.removeEventListener('change', app.fileInputListener);
      }
      app.fileInputListener = null;
    }

    app.createSchedule.uploadedAttachments.forEach(attachment => {
      if (attachment.previewUrl) {
        URL.revokeObjectURL(attachment.previewUrl);
      }
    });

    app.createSchedule.uploadedAttachments = [];
    app.createSchedule.attachmentProgress = {};
    app.createSchedule.attachmentUploadMeta = {};
    app.createSchedule.attachmentUploadTicker = 0;
    app.createSchedule.attachmentSessionId = null;
    app.createSchedule.sessionCreationPromise = null;
    app.stopAttachmentUploadTicker();
  }
  ,
  openAttachmentViewer(attachment = null, options = {}) {
    if (!attachment) {
      return;
    }

    const {onClose} = options;
    const fileName = attachment.originalFilename || attachment.name || '이미지';
    const escapeHtml = (value) => value
      ? value.replace(/[&<>"']/g, (char) => {
        switch (char) {
          case '&':
            return '&amp;';
          case '<':
            return '&lt;';
          case '>':
            return '&gt;';
          case '"':
            return '&quot;';
          case '\'':
            return '&#39;';
          default:
            return char;
        }
      })
      : '';

    let imageSource = attachment.previewUrl;
    if (!imageSource) {
      const baseDownloadUrl = attachment.downloadUrl || (attachment.id ? `/api/attachments/${attachment.id}/download` : null);
      if (baseDownloadUrl) {
        imageSource = `${baseDownloadUrl}?inline=true`;
      }
    }
    if (!imageSource && attachment.thumbnailUrl) {
      imageSource = attachment.thumbnailUrl;
    }

    if (!imageSource) {
      Swal.fire({
        icon: 'error',
        title: '이미지를 불러오지 못했습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      return;
    }

    return Swal.fire({
      html: `<div class="attachment-viewer-body"><img src="${imageSource}" alt="${escapeHtml(fileName)}" class="attachment-viewer-img"></div>`,
      showConfirmButton: false,
      showCloseButton: true,
      focusConfirm: false,
      background: '#000',
      customClass: {
        popup: 'attachment-viewer-popup',
        title: 'attachment-viewer-title',
        htmlContainer: 'attachment-viewer-html',
        closeButton: 'attachment-viewer-close'
      }
    }).then((result) => {
      if (typeof onClose === 'function') {
        onClose(result);
      }
      return result;
    });
  }
  ,
  attachmentIconClass(attachment) {
    if (!attachment) {
      return 'bi-file-earmark';
    }
    const filename = (attachment.originalFilename || attachment.name || '').toLowerCase();
    const extension = getFileExtension(filename);
    if (extension && ATTACHMENT_ICON_BY_EXTENSION[extension]) {
      return ATTACHMENT_ICON_BY_EXTENSION[extension];
    }
    const contentType = (attachment.contentType || attachment.type || '').toLowerCase();
    if (contentType) {
      if (ATTACHMENT_ICON_BY_CONTENT_TYPE[contentType]) {
        return ATTACHMENT_ICON_BY_CONTENT_TYPE[contentType];
      }
      if (contentType.startsWith('image/')) {
        return 'bi-file-earmark-image';
      }
      if (contentType.startsWith('audio/')) {
        return 'bi-file-earmark-music';
      }
      if (contentType.startsWith('video/')) {
        return 'bi-file-earmark-play';
      }
      if (contentType.includes('zip') || contentType.includes('rar') || contentType.includes('compressed')) {
        return 'bi-file-earmark-zip';
      }
      if (contentType.includes('pdf')) {
        return 'bi-file-earmark-pdf';
      }
      if (contentType.includes('word')) {
        return 'bi-file-earmark-word';
      }
      if (contentType.includes('excel') || contentType.includes('spreadsheet')) {
        return 'bi-file-earmark-spreadsheet';
      }
      if (contentType.includes('presentation') || contentType.includes('powerpoint')) {
        return 'bi-file-earmark-ppt';
      }
      if (contentType.startsWith('text/')) {
        return 'bi-file-earmark-text';
      }
      if (contentType.includes('json') || contentType.includes('xml') || contentType.includes('javascript')) {
        return 'bi-file-earmark-code';
      }
      if (contentType.includes('binary') || contentType.includes('octet-stream')) {
        return 'bi-file-earmark-binary';
      }
    }
    return 'bi-file-earmark';
  }
  ,
  startAttachmentUploadTicker() {
    if (this.attachmentUploadTickerInterval) {
      return;
    }
    this.attachmentUploadTickerInterval = window.setInterval(() => {
      this.createSchedule.attachmentUploadTicker = Date.now();
    }, 500);
    this.createSchedule.attachmentUploadTicker = Date.now();
  }
  ,
  stopAttachmentUploadTicker() {
    if (this.attachmentUploadTickerInterval) {
      clearInterval(this.attachmentUploadTickerInterval);
      this.attachmentUploadTickerInterval = null;
    }
    this.createSchedule.attachmentUploadTicker = 0;
  }
  ,
  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  }
  ,
  formatDuration(seconds) {
    if (seconds === null || seconds === undefined || Number.isNaN(seconds) || !Number.isFinite(seconds)) {
      return '계산 중';
    }
    const totalSeconds = Math.max(Math.floor(seconds), 0);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const secs = totalSeconds % 60;
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  ,
}
