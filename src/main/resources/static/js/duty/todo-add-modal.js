const todoAttachmentHelpers = window.todoAttachmentHelpers || (() => {
  const validationConfig = window.AttachmentValidation || {
    maxFileSizeBytes: 50 * 1024 * 1024,
    maxFileSizeLabel: '50MB',
    tooLargeMessage(filename) {
      const prefix = filename ? `${filename} 파일은` : '파일이';
      const label = this.maxFileSizeLabel ? `(${this.maxFileSizeLabel})` : '';
      return `${prefix} 허용 용량${label}을 초과해 업로드할 수 없습니다.`;
    },
    blockedExtensionMessage(filename) {
      const target = filename ? `${filename} 파일은` : '이 파일은';
      return `${target} 업로드할 수 없는 확장자입니다.`;
    }
  };

  const normalizeAttachmentDto = (dto) => ({
    id: dto.id,
    name: dto.originalFilename,
    originalFilename: dto.originalFilename,
    contentType: dto.contentType,
    size: dto.size,
    thumbnailUrl: dto.thumbnailUrl,
    downloadUrl: `/api/attachments/${dto.id}/download`,
    isImage: dto.contentType ? dto.contentType.startsWith('image/') : false,
    hasThumbnail: dto.hasThumbnail,
    orderIndex: dto.orderIndex,
    createdAt: dto.createdAt,
    createdBy: dto.createdBy,
    previewUrl: null,
  });

  const getFileExtension = (filename) => {
    if (!filename || filename.indexOf('.') === -1) {
      return '';
    }
    return filename.split('.').pop().toLowerCase();
  };

  const attachmentIconClass = (attachment) => {
    if (!attachment) {
      return 'bi-file-earmark';
    }
    const filename = (attachment.originalFilename || attachment.name || '').toLowerCase();
    const ext = getFileExtension(filename);
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic', 'heif'].includes(ext)) {
      return 'bi-file-earmark-image';
    }
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].includes(ext)) {
      return 'bi-file-earmark-play';
    }
    if (['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'].includes(ext)) {
      return 'bi-file-earmark-music';
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].includes(ext)) {
      return 'bi-file-earmark-zip';
    }
    if (ext === 'pdf') {
      return 'bi-file-earmark-pdf';
    }
    if (['doc', 'docx'].includes(ext)) {
      return 'bi-file-earmark-word';
    }
    if (['xls', 'xlsx', 'csv'].includes(ext)) {
      return 'bi-file-earmark-spreadsheet';
    }
    if (['ppt', 'pptx'].includes(ext)) {
      return 'bi-file-earmark-ppt';
    }
    if (['txt', 'md', 'log'].includes(ext)) {
      return 'bi-file-earmark-text';
    }
    return 'bi-file-earmark';
  };

  const showAlert = (message) => {
    Swal.fire({
      icon: 'error',
      title: message,
      showConfirmButton: false,
      timer: 2500
    });
  };

  const validateFile = (file) => {
    if (!file) {
      return {valid: false, message: '업로드할 파일을 찾지 못했습니다.'};
    }
    if (file.size > validationConfig.maxFileSizeBytes) {
      return {
        valid: false,
        message: validationConfig.tooLargeMessage(file.name)
      };
    }
    return {valid: true};
  };

  const buildUploadProgressPayload = (event) => {
    const payload = {
      bytesUploaded: event.loaded || 0,
      bytesTotal: event.total || 0,
    };
    payload.percentage = (event.lengthComputable && event.total > 0)
      ? Math.round((event.loaded / event.total) * 100)
      : 0;
    return payload;
  };

  const handleXhrError = (xhr, file) => {
    const fileName = file?.name;
    if (xhr.status === 0) {
      showAlert('네트워크 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      return new Error('Network error during attachment upload');
    }
    if (xhr.status === 413) {
      const message = xhr.response?.message || validationConfig.tooLargeMessage(fileName);
      showAlert(message);
      return new Error(message);
    }
    if (xhr.status === 400 && xhr.response?.code === 'ATTACHMENT_EXTENSION_BLOCKED' && fileName) {
      const message = validationConfig.blockedExtensionMessage(fileName);
      showAlert(message);
      return new Error(message);
    }
    const message = xhr.response?.message || '파일 업로드에 실패했습니다.';
    showAlert(message);
    return new Error(message);
  };

  const formatBytes = (bytes) => {
    if (!bytes) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  };

  const escapeHtml = (value) => value
    ? value.replace(/[&<>\"']/g, (char) => {
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

  const openViewer = (attachment) => {
    if (!attachment) return;
    const fileName = attachment.originalFilename || attachment.name || '이미지';
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
      showAlert('이미지를 불러오지 못했습니다.');
      return;
    }
    return Swal.fire({
      html: `<div class="attachment-viewer-body"><img src="${imageSource}" alt="${escapeHtml(fileName)}" class="attachment-viewer-img"></div>`,
      showConfirmButton: false,
      showCloseButton: true,
      background: '#000',
      customClass: {
        popup: 'attachment-viewer-popup',
        title: 'attachment-viewer-title',
        htmlContainer: 'attachment-viewer-html',
        closeButton: 'attachment-viewer-close'
      },
      didOpen: () => {
        const img = document.querySelector('.attachment-viewer-img');
        if (img) {
          img.addEventListener('click', (event) => {
            const rect = img.getBoundingClientRect();
            const x = ((event.clientX - rect.left) / rect.width) * 100;
            const y = ((event.clientY - rect.top) / rect.height) * 100;

            if (img.classList.contains('zoomed')) {
              img.classList.remove('zoomed');
              img.style.transformOrigin = '';
            } else {
              img.style.transformOrigin = `${x}% ${y}%`;
              img.classList.add('zoomed');
            }
          });
        }
      }
    });
  };

  const fetchJson = async (url, options, fallbackMessage) => {
    const response = await fetch(url, options);
    if (!response.ok) {
      let message = fallbackMessage;
      try {
        const body = await response.json();
        if (body?.message) {
          message = body.message;
        }
      } catch {
        // ignore
      }
      showAlert(message);
      throw new Error(message);
    }
    return response.json();
  };

  const createSession = async (targetContextId = null) => {
    return fetchJson('/api/attachments/sessions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        contextType: 'TODO',
        targetContextId: targetContextId
      })
    }, '파일 업로드 세션 생성에 실패했습니다.');
  };

  const deleteSession = async (sessionId) => {
    if (!sessionId) {
      return;
    }
    try {
      await fetch(`/api/attachments/sessions/${sessionId}`, {
        method: 'DELETE'
      });
    } catch (error) {
      console.warn('Failed to discard attachment session:', error);
    }
  };

  const listAttachments = async (todoId) => {
    const response = await fetch(`/api/attachments?contextType=TODO&contextId=${todoId}`, {
      method: 'GET'
    });
    if (!response.ok) {
      showAlert('첨부파일을 불러오지 못했습니다.');
      return [];
    }
    const attachments = await response.json();
    return attachments.map(normalizeAttachmentDto);
  };

  return {
    validationConfig,
    normalizeAttachmentDto,
    attachmentIconClass,
    showAlert,
    validateFile,
    buildUploadProgressPayload,
    handleXhrError,
    formatBytes,
    openViewer,
    createSession,
    deleteSession,
    listAttachments
  };
})();
window.todoAttachmentHelpers = todoAttachmentHelpers;

const todoAddMethods = {
  async todoAddInitializeAttachmentUploader() {
    const app = this;
    const state = app.newTodo;

    if (app.todoAddUppyInstance) {
      try {
        app.todoAddUppyInstance.cancelAll();
      } catch (e) {
        console.warn('Error cleaning up previous Uppy instance:', e);
      }
      app.todoAddUppyInstance = null;
    }

    if (app.todoAddFileInputListener) {
      const prevInput = document.getElementById('todo-add-attachment-input');
      if (prevInput) {
        prevInput.removeEventListener('change', app.todoAddFileInputListener);
      }
      app.todoAddFileInputListener = null;
    }

    try {
      const {Uppy, XHRUpload} = await import('/lib/uppy-5.1.7/uppy.min.mjs');
      const ATTACHMENT_SESSION_ERROR = 'ATTACHMENT_SESSION_CREATION_FAILED';

      const ensureAttachmentSession = async () => {
        if (state.attachmentSessionId) {
          return state.attachmentSessionId;
        }
        if (!state.sessionCreationPromise) {
          state.sessionCreationPromise = todoAttachmentHelpers.createSession(null)
            .then((session) => {
              state.attachmentSessionId = session.sessionId;
              return session.sessionId;
            });
        }
        try {
          const sessionId = await state.sessionCreationPromise;
          state.sessionCreationPromise = null;
          return sessionId;
        } catch (error) {
          state.sessionCreationPromise = null;
          throw error;
        }
      };

      const uppy = new Uppy({
        restrictions: {
          maxFileSize: todoAttachmentHelpers.validationConfig.maxFileSizeBytes,
          allowedFileTypes: null,
        },
        autoProceed: true,
      }).use(XHRUpload, {
        endpoint: '/api/attachments',
        fieldName: 'file',
        formData: true,
        bundle: false,
        headers: {},
        getResponseData(responseText) {
          const text = typeof responseText === 'string' ? responseText : (responseText.responseText || responseText.response);
          try {
            return JSON.parse(text);
          } catch (e) {
            console.error('Failed to parse JSON response:', text);
            throw new Error(`Invalid JSON response: ${text ? text.substring(0, 100) : 'empty'}`);
          }
        },
      });

      uppy.on('file-added', (file) => {
        const fileData = file?.data;
        const validation = todoAttachmentHelpers.validateFile(fileData);
        if (!validation.valid) {
          uppy.removeFile(file.id);
          todoAttachmentHelpers.showAlert(validation.message);
          return;
        }

        const fileType = fileData?.type || '';
        const tempAttachment = {
          id: file.id,
          name: file.name,
          originalFilename: file.name,
          contentType: fileType,
          size: fileData?.size || 0,
          isImage: fileType.startsWith('image/'),
          hasThumbnail: false,
          previewUrl: fileType.startsWith('image/') ? URL.createObjectURL(fileData) : null,
          downloadUrl: null,
        };

        state.uploadedAttachments.push(tempAttachment);
        if (typeof app.$set === 'function') {
          app.$set(state.attachmentProgress, file.id, 0);
          app.$set(state.attachmentUploadMeta, file.id, {
            bytesUploaded: 0,
            bytesTotal: fileData?.size || 0,
            startedAt: Date.now(),
            lastUpdatedAt: Date.now(),
          });
        } else {
          state.attachmentProgress[file.id] = 0;
          state.attachmentUploadMeta[file.id] = {
            bytesUploaded: 0,
            bytesTotal: fileData?.size || 0,
            startedAt: Date.now(),
            lastUpdatedAt: Date.now(),
          };
        }
        this.todoAddStartAttachmentUploadTicker();
      });

      uppy.on('restriction-failed', (file, error) => {
        if (error && /already been added/i.test((error.message || '').toLowerCase())) {
          try {
            uppy.addFile({
              id: `${file.id}-${Date.now()}`,
              name: file.name,
              type: file.type,
              data: file.data,
              meta: {...(file.meta || {})},
            });
            return;
          } catch (duplicateError) {
            console.warn('Failed to add duplicate attachment:', duplicateError);
          }
        }
        if (error && (error.isRestriction || /maximum allowed size/i.test(error.message || ''))) {
          todoAttachmentHelpers.showAlert(todoAttachmentHelpers.validationConfig.tooLargeMessage(file?.name));
        } else {
          todoAttachmentHelpers.showAlert('파일 추가에 실패했습니다.');
        }
      });

      uppy.addPreProcessor(async (fileIDs) => {
        if (!fileIDs || fileIDs.length === 0) {
          return;
        }
        let sessionId;
        try {
          sessionId = await ensureAttachmentSession();
        } catch (error) {
          console.error('Failed to ensure attachment session before upload:', error);
          todoAttachmentHelpers.showAlert('파일 업로드 세션 생성에 실패했습니다.');
          fileIDs.forEach((fileId) => {
            const file = uppy.getFile(fileId);
            if (file) {
              uppy.removeFile(fileId);
            }
            if (typeof app.$delete === 'function') {
              app.$delete(state.attachmentProgress, fileId);
              if (state.attachmentUploadMeta && state.attachmentUploadMeta[fileId]) {
                app.$delete(state.attachmentUploadMeta, fileId);
              }
            } else {
              delete state.attachmentProgress[fileId];
              if (state.attachmentUploadMeta && state.attachmentUploadMeta[fileId]) {
                delete state.attachmentUploadMeta[fileId];
              }
            }
            const index = state.uploadedAttachments.findIndex(a => a.id === fileId);
            if (index !== -1) {
              const attachment = state.uploadedAttachments[index];
              if (attachment.previewUrl) {
                URL.revokeObjectURL(attachment.previewUrl);
              }
              state.uploadedAttachments.splice(index, 1);
            }
          });
          if (Object.keys(state.attachmentUploadMeta || {}).length === 0) {
            this.todoAddStopAttachmentUploadTicker();
          }
          throw new Error(ATTACHMENT_SESSION_ERROR);
        }
        fileIDs.forEach((fileId) => {
          const file = uppy.getFile(fileId);
          if (!file) {
            return;
          }
          uppy.setFileMeta(fileId, {
            ...file.meta,
            sessionId: String(sessionId),
          });
        });
      });

      uppy.on('upload-progress', (file, progress) => {
        const payload = todoAttachmentHelpers.buildUploadProgressPayload(progress);
        if (typeof app.$set === 'function') {
          app.$set(state.attachmentProgress, file.id, payload.percentage);
        } else {
          state.attachmentProgress[file.id] = payload.percentage;
        }
        const meta = state.attachmentUploadMeta ? state.attachmentUploadMeta[file.id] : null;
        if (meta) {
          meta.bytesUploaded = payload.bytesUploaded;
          meta.bytesTotal = payload.bytesTotal;
          meta.lastUpdatedAt = Date.now();
        }
      });

      uppy.on('upload-success', (file, response) => {
        const attachmentDto = response.body;
        const normalized = todoAttachmentHelpers.normalizeAttachmentDto(attachmentDto);
        const fileType = file?.data?.type || '';
        const index = state.uploadedAttachments.findIndex(a => a.id === file.id);
        if (index !== -1) {
          const oldPreviewUrl = state.uploadedAttachments[index].previewUrl;
          if (fileType.startsWith('image/') && !normalized.previewUrl) {
            normalized.previewUrl = oldPreviewUrl;
          }
          app.$set(state.uploadedAttachments, index, normalized);
        }
        if (typeof app.$delete === 'function') {
          app.$delete(state.attachmentProgress, file.id);
        } else {
          delete state.attachmentProgress[file.id];
        }
        if (state.attachmentUploadMeta && state.attachmentUploadMeta[file.id]) {
          if (typeof app.$delete === 'function') {
            app.$delete(state.attachmentUploadMeta, file.id);
          } else {
            delete state.attachmentUploadMeta[file.id];
          }
        }
        if (Object.keys(state.attachmentUploadMeta || {}).length === 0) {
          this.todoAddStopAttachmentUploadTicker();
        }
      });

      uppy.on('upload-error', (file, error, response) => {
        if (error?.message === ATTACHMENT_SESSION_ERROR) {
          return;
        }
        console.error('Upload error:', error, response);
        const index = state.uploadedAttachments.findIndex(a => a.id === file.id);
        if (index !== -1) {
          const attachment = state.uploadedAttachments[index];
          if (attachment.previewUrl) {
            URL.revokeObjectURL(attachment.previewUrl);
          }
          state.uploadedAttachments.splice(index, 1);
        }
        if (typeof app.$delete === 'function') {
          app.$delete(state.attachmentProgress, file.id);
        } else {
          delete state.attachmentProgress[file.id];
        }
        if (state.attachmentUploadMeta && state.attachmentUploadMeta[file.id]) {
          if (typeof app.$delete === 'function') {
            app.$delete(state.attachmentUploadMeta, file.id);
          } else {
            delete state.attachmentUploadMeta[file.id];
          }
        }
        if (Object.keys(state.attachmentUploadMeta || {}).length === 0) {
          this.todoAddStopAttachmentUploadTicker();
        }
        if (response && response.body) {
          todoAttachmentHelpers.handleXhrError({status: response.status, response: response.body}, file?.data);
        } else {
          todoAttachmentHelpers.showAlert('파일 업로드에 실패했습니다.');
        }
      });

      app.todoAddFileInputListener = (event) => {
        const files = Array.from(event.target.files);
        files.forEach(file => {
          try {
            const uniqueId = `${file.name}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
            uppy.addFile({
              id: uniqueId,
              name: file.name,
              type: file.type,
              data: file,
            });
          } catch (err) {
            console.error('Failed to add file:', err);
            if (err && (err.isRestriction || /maximum allowed size/i.test(err.message || ''))) {
              todoAttachmentHelpers.showAlert(todoAttachmentHelpers.validationConfig.tooLargeMessage(file.name));
            } else {
              todoAttachmentHelpers.showAlert(`파일 추가에 실패했습니다: ${file.name}`);
            }
          }
        });
        event.target.value = '';
      };

      await app.$nextTick();
      const fileInput = document.getElementById('todo-add-attachment-input');
      if (fileInput) {
        fileInput.addEventListener('change', app.todoAddFileInputListener);
      }

      app.todoAddUppyInstance = uppy;
    } catch (error) {
      console.error('Failed to initialize attachment uploader:', error);
      todoAttachmentHelpers.showAlert('첨부파일 업로드 기능을 초기화하지 못했습니다.');
    }
  }
  ,
  todoAddStartAttachmentUploadTicker() {
    if (this.newTodo.uploadTickerInterval) {
      return;
    }
    this.newTodo.uploadTickerInterval = window.setInterval(() => {
      this.newTodo.attachmentUploadTicker = Date.now();
    }, 500);
    this.newTodo.attachmentUploadTicker = Date.now();
  }
  ,
  todoAddStopAttachmentUploadTicker() {
    if (this.newTodo.uploadTickerInterval) {
      clearInterval(this.newTodo.uploadTickerInterval);
      this.newTodo.uploadTickerInterval = null;
    }
    this.newTodo.attachmentUploadTicker = 0;
  }
  ,
  todoAddRemoveAttachment(attachmentId) {
    const state = this.newTodo;
    const index = state.uploadedAttachments.findIndex(a => a.id === attachmentId);
    if (index === -1) {
      return;
    }
    const attachment = state.uploadedAttachments[index];
    if (attachment.previewUrl) {
      URL.revokeObjectURL(attachment.previewUrl);
    }
    state.uploadedAttachments.splice(index, 1);
    if (typeof this.$delete === 'function') {
      this.$delete(state.attachmentProgress, attachmentId);
    } else {
      delete state.attachmentProgress[attachmentId];
    }
    if (state.attachmentUploadMeta && state.attachmentUploadMeta[attachmentId]) {
      if (typeof this.$delete === 'function') {
        this.$delete(state.attachmentUploadMeta, attachmentId);
      } else {
        delete state.attachmentUploadMeta[attachmentId];
      }
    }
    if (Object.keys(state.attachmentUploadMeta || {}).length === 0) {
      this.todoAddStopAttachmentUploadTicker();
    }
    if (this.todoAddUppyInstance) {
      const uploadingFile = this.todoAddUppyInstance.getFile(attachmentId);
      if (uploadingFile) {
        try {
          this.todoAddUppyInstance.removeFile(attachmentId);
        } catch (error) {
          console.warn('Failed to remove file from uploader:', error);
        }
      }
    }
  }
  ,
  todoAddCleanupAttachmentState() {
    const state = this.newTodo;
    state.uploadedAttachments.forEach(attachment => {
      if (attachment.previewUrl) {
        URL.revokeObjectURL(attachment.previewUrl);
      }
    });
    state.uploadedAttachments = [];
    state.attachmentProgress = {};
    state.attachmentUploadMeta = {};
    state.attachmentUploadTicker = 0;
    state.attachmentSessionId = null;
    state.sessionCreationPromise = null;
    this.todoAddStopAttachmentUploadTicker();
  }
  ,
  todoAddDisposeUploader() {
    if (this.todoAddUppyInstance) {
      try {
        this.todoAddUppyInstance.cancelAll();
      } catch (e) {
        console.warn('Error cleaning up Uppy instance:', e);
      }
      this.todoAddUppyInstance = null;
    }
    if (this.todoAddFileInputListener) {
      const fileInput = document.getElementById('todo-add-attachment-input');
      if (fileInput) {
        fileInput.removeEventListener('change', this.todoAddFileInputListener);
      }
      this.todoAddFileInputListener = null;
    }
  }
  ,
  async todoAddDiscardSession() {
    await todoAttachmentHelpers.deleteSession(this.newTodo.attachmentSessionId);
  }
  ,
  todoAddOpenAttachmentViewer(attachment) {
    if (!attachment || !attachment.isImage) {
      return;
    }
    todoAttachmentHelpers.openViewer(attachment);
  }
  ,
  todoAddAttachmentIconClass(attachment) {
    return todoAttachmentHelpers.attachmentIconClass(attachment);
  }
  ,
  todoAddFormatBytes(bytes) {
    return todoAttachmentHelpers.formatBytes(bytes);
  }
  ,
  async addTodo() {
    const app = this;
    const addTodoModal = document.getElementById('add-todo-modal');
    const title = addTodoModal.querySelector('.todo-title').value.trim();
    const content = addTodoModal.querySelector('.todo-content').value.trim();
    if (!title) {
      app.alertTodoTitle();
      return;
    }
    if (Object.keys(app.newTodo.attachmentProgress || {}).length > 0) {
      todoAttachmentHelpers.showAlert('파일 업로드가 진행 중입니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    const orderedAttachmentIds = app.newTodo.uploadedAttachments.map(a => a.id);

    fetch('/api/todos', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title: title,
        content: content,
        attachmentSessionId: app.newTodo.attachmentSessionId,
        orderedAttachmentIds: orderedAttachmentIds,
      })
    }).then(async response => {
      if (!response.ok) {
        todoAttachmentHelpers.showAlert('할 일 추가에 실패했습니다.');
        return;
      }
      await app.todoAddDiscardSession();
      app.todoAddCleanupAttachmentState();
      app.todoAddDisposeUploader();
      Swal.fire({
        icon: 'success',
        title: '할 일이 추가되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      app.loadTodos();
      $('#add-todo-modal').modal('hide');
    });
  }
  ,
  cancelAddTodo(skipModalHide = false) {
    this.todoAddDiscardSession();
    this.todoAddCleanupAttachmentState();
    this.todoAddDisposeUploader();
    this.newTodo.title = '';
    this.newTodo.content = '';
    const modal = document.getElementById('add-todo-modal');
    if (modal) {
      modal.querySelector('.todo-title').value = '';
      modal.querySelector('.todo-content').value = '';
    }
    if (!skipModalHide) {
      $('#add-todo-modal').modal('hide');
    }
  }
  ,
  alertTodoTitle() {
    Swal.fire({
      icon: 'error',
      title: '할일 제목을 입력해주세요.',
      showConfirmButton: false,
      timer: sweetAlTimer
    });
  },
};
