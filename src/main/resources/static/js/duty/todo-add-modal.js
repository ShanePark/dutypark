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
    listAttachments,
    createUppyUploader: base.createUppyUploader,
    setupDropZone: base.setupDropZone,
    cleanupDropZone: base.cleanupDropZone,
  };
})();
window.todoAttachmentHelpers = todoAttachmentHelpers;

const todoAddMethods = {
  async todoAddInitializeAttachmentUploader() {
    const app = this;

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

    if (app.todoAddDropZoneListeners) {
      todoAttachmentHelpers.cleanupDropZone('label[for="todo-add-attachment-input"]', app.todoAddDropZoneListeners);
      app.todoAddDropZoneListeners = null;
    }

    try {
      const uploader = await todoAttachmentHelpers.createUppyUploader({
        state: app.newTodo,
        fileInputId: 'todo-add-attachment-input',
        createSessionFn: todoAttachmentHelpers.createSession,
        showAlertFn: todoAttachmentHelpers.showAlert,
        handleXhrErrorFn: todoAttachmentHelpers.handleXhrError,
        normalizeDtoFn: todoAttachmentHelpers.normalizeAttachmentDto,
        resolveDtoUrlFn: todoAttachmentHelpers.resolveDownloadUrl,
        startTickerFn: () => this.todoAddStartAttachmentUploadTicker(),
        stopTickerFn: () => this.todoAddStopAttachmentUploadTicker(),
        validation: todoAttachmentHelpers.validationConfig,
        vueApp: app,
        useUniqueFileId: true,
      });

      app.todoAddUppyInstance = uploader.uppyInstance;
      app.todoAddFileInputListener = uploader.fileInputListener;

      if (app.todoAddUppyInstance) {
        app.todoAddDropZoneListeners = todoAttachmentHelpers.setupDropZone('label[for="todo-add-attachment-input"]', app.todoAddUppyInstance);
      }
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
    if (this.todoAddDropZoneListeners) {
      todoAttachmentHelpers.cleanupDropZone('label[for="todo-add-attachment-input"]', this.todoAddDropZoneListeners);
      this.todoAddDropZoneListeners = null;
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
