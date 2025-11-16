const todoAttachmentHelpers = window.todoAttachmentHelpers || (() => {
  const base = window.AttachmentHelpers;
  const showAlert = (message) => base.showAlert(message, {showConfirmButton: false, timer: 2500});
  const handleXhrError = (xhr, file) => base.handleXhrError(xhr, file, {alertOptions: {showConfirmButton: false, timer: 2500}});

  const createSession = async (targetContextId = null) => base.createSession({
    contextType: 'TODO',
    targetContextId
  });

  const deleteSession = async (sessionId) => base.deleteSession(sessionId);

  const listAttachments = async (todoId) => base.listAttachments({
    contextType: 'TODO',
    contextId: todoId
  });

  return {
    validationConfig: base.validationConfig,
    normalizeAttachmentDto: base.normalizeAttachmentDto,
    attachmentIconClass: base.attachmentIconClass,
    showAlert,
    validateFile: (file) => base.validateFile(file),
    buildUploadProgressPayload: base.buildUploadProgressPayload,
    handleXhrError,
    formatBytes: base.formatBytes,
    openViewer: (attachment) => base.openViewer(attachment, {missingMessage: '이미지를 불러오지 못했습니다.'}),
    resolveDownloadUrl: base.resolveDownloadUrl,
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
        if (error && /duplicate|already/i.test(error.message || '')) {
          todoAttachmentHelpers.showAlert(todoAttachmentHelpers.validationConfig.duplicateFileMessage(file?.name));
        } else if (error && (error.isRestriction || /maximum allowed size/i.test(error.message || ''))) {
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
          if (fileType.startsWith('image/')) {
            const inlinePreviewUrl = todoAttachmentHelpers.resolveDownloadUrl(normalized, {inline: true});
            if (inlinePreviewUrl) {
              normalized.previewUrl = inlinePreviewUrl;
              if (oldPreviewUrl && oldPreviewUrl.startsWith('blob:')) {
                URL.revokeObjectURL(oldPreviewUrl);
              }
            } else if (!normalized.previewUrl) {
              normalized.previewUrl = oldPreviewUrl;
            }
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
            if (err && /duplicate|already/i.test(err.message || '')) {
              todoAttachmentHelpers.showAlert(todoAttachmentHelpers.validationConfig.duplicateFileMessage(file.name));
            } else if (err && (err.isRestriction || /maximum allowed size/i.test(err.message || ''))) {
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
  todoAddAttachmentDownloadUrl(attachment) {
    return todoAttachmentHelpers.resolveDownloadUrl(attachment);
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
