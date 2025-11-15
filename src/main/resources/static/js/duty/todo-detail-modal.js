const todoDetailMethods = {
  async loadTodoAttachments(todoId) {
    const attachments = await todoAttachmentHelpers.listAttachments(todoId);
    this.selectedTodoAttachments = attachments;
    if (!this.editTodoMode) {
      this.editTodo.uploadedAttachments = attachments.map(attachment => ({...attachment}));
    }
  }
  ,
  async enterEditMode() {
    const modal = document.getElementById('todo-details-modal');
    this.originalTodoTitle = modal.querySelector('.todo-title').value;
    this.originalTodoContent = modal.querySelector('.todo-content').value;
    this.editTodoMode = true;
    this.editTodo.title = this.originalTodoTitle;
    this.editTodo.content = this.originalTodoContent;
    this.editTodo.uploadedAttachments = this.selectedTodoAttachments.map(attachment => ({...attachment}));
    await this.$nextTick();
    this.todoDetailInitializeAttachmentUploader();
  }
  ,
  cancelEdit() {
    const modal = document.getElementById('todo-details-modal');
    modal.querySelector('.todo-title').value = this.originalTodoTitle;
    modal.querySelector('.todo-content').value = this.originalTodoContent;
    this.exitTodoDetailAttachments(true);
  }
  ,
  exitTodoDetailAttachments(skipModalHide = false) {
    this.todoDetailDiscardSession();
    this.todoDetailCleanupAttachmentState();
    this.todoDetailDisposeUploader();
    this.editTodoMode = false;
    const modal = document.getElementById('todo-details-modal');
    if (modal) {
      modal.querySelector('.todo-title').value = this.editTodo.title || this.originalTodoTitle;
      modal.querySelector('.todo-content').value = this.editTodo.content || this.originalTodoContent;
    }
    if (!skipModalHide) {
      $('#todo-details-modal').modal('hide');
    }
  }
  ,
  async todoDetailInitializeAttachmentUploader() {
    const app = this;
    const state = app.editTodo;

    if (app.todoDetailUppyInstance) {
      try {
        app.todoDetailUppyInstance.cancelAll();
      } catch (e) {
        console.warn('Error cleaning up previous Uppy instance:', e);
      }
      app.todoDetailUppyInstance = null;
    }

    if (app.todoDetailFileInputListener) {
      const prevInput = document.getElementById('todo-detail-attachment-input');
      if (prevInput) {
        prevInput.removeEventListener('change', app.todoDetailFileInputListener);
      }
      app.todoDetailFileInputListener = null;
    }

    try {
      const {Uppy, XHRUpload} = await import('/lib/uppy-5.1.7/uppy.min.mjs');
      const ATTACHMENT_SESSION_ERROR = 'ATTACHMENT_SESSION_CREATION_FAILED';

      const ensureAttachmentSession = async () => {
        const modal = document.getElementById('todo-details-modal');
        const todoId = modal ? modal.getAttribute('data-id') : null;
        if (state.attachmentSessionId) {
          return state.attachmentSessionId;
        }
        if (!state.sessionCreationPromise) {
          state.sessionCreationPromise = todoAttachmentHelpers.createSession(todoId)
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
        this.todoDetailStartAttachmentUploadTicker();
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
            this.todoDetailStopAttachmentUploadTicker();
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
          this.todoDetailStopAttachmentUploadTicker();
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
          this.todoDetailStopAttachmentUploadTicker();
        }
        if (response && response.body) {
          todoAttachmentHelpers.handleXhrError({status: response.status, response: response.body}, file?.data);
        } else {
          todoAttachmentHelpers.showAlert('파일 업로드에 실패했습니다.');
        }
      });

      app.todoDetailFileInputListener = (event) => {
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
      const fileInput = document.getElementById('todo-detail-attachment-input');
      if (fileInput) {
        fileInput.addEventListener('change', app.todoDetailFileInputListener);
      }

      app.todoDetailUppyInstance = uppy;
    } catch (error) {
      console.error('Failed to initialize attachment uploader:', error);
      todoAttachmentHelpers.showAlert('첨부파일 업로드 기능을 초기화하지 못했습니다.');
    }
  }
  ,
  todoDetailStartAttachmentUploadTicker() {
    if (this.editTodo.uploadTickerInterval) {
      return;
    }
    this.editTodo.uploadTickerInterval = window.setInterval(() => {
      this.editTodo.attachmentUploadTicker = Date.now();
    }, 500);
    this.editTodo.attachmentUploadTicker = Date.now();
  }
  ,
  todoDetailStopAttachmentUploadTicker() {
    if (this.editTodo.uploadTickerInterval) {
      clearInterval(this.editTodo.uploadTickerInterval);
      this.editTodo.uploadTickerInterval = null;
    }
    this.editTodo.attachmentUploadTicker = 0;
  }
  ,
  todoDetailRemoveAttachment(attachmentId) {
    const state = this.editTodo;
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
      this.todoDetailStopAttachmentUploadTicker();
    }
    if (this.todoDetailUppyInstance) {
      const uploadingFile = this.todoDetailUppyInstance.getFile(attachmentId);
      if (uploadingFile) {
        try {
          this.todoDetailUppyInstance.removeFile(attachmentId);
        } catch (error) {
          console.warn('Failed to remove file from uploader:', error);
        }
      }
    }
  }
  ,
  todoDetailCleanupAttachmentState() {
    const state = this.editTodo;
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
    this.todoDetailStopAttachmentUploadTicker();
  }
  ,
  todoDetailDisposeUploader() {
    if (this.todoDetailUppyInstance) {
      try {
        this.todoDetailUppyInstance.cancelAll();
      } catch (e) {
        console.warn('Error cleaning up Uppy instance:', e);
      }
      this.todoDetailUppyInstance = null;
    }
    if (this.todoDetailFileInputListener) {
      const fileInput = document.getElementById('todo-detail-attachment-input');
      if (fileInput) {
        fileInput.removeEventListener('change', this.todoDetailFileInputListener);
      }
      this.todoDetailFileInputListener = null;
    }
  }
  ,
  async todoDetailDiscardSession() {
    await todoAttachmentHelpers.deleteSession(this.editTodo.attachmentSessionId);
  }
  ,
  todoDetailOpenAttachmentViewer(attachment) {
    if (!attachment || !attachment.isImage) {
      return;
    }
    todoAttachmentHelpers.openViewer(attachment);
  }
  ,
  todoDetailAttachmentIconClass(attachment) {
    return todoAttachmentHelpers.attachmentIconClass(attachment);
  }
  ,
  todoDetailFormatBytes(bytes) {
    return todoAttachmentHelpers.formatBytes(bytes);
  }
  ,
  todoDetailAttachmentDownloadUrl(attachment) {
    return todoAttachmentHelpers.resolveDownloadUrl(attachment);
  }
  ,
  updateTodo() {
    const app = this;
    const modal = document.getElementById("todo-details-modal");
    const todoId = modal.getAttribute('data-id');
    const title = modal.querySelector('.todo-title').value.trim();
    const content = modal.querySelector('.todo-content').value.trim();

    if (!title) {
      app.alertTodoTitle();
      return;
    }
    if (Object.keys(app.editTodo.attachmentProgress || {}).length > 0) {
      todoAttachmentHelpers.showAlert('파일 업로드가 진행 중입니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    const orderedAttachmentIds = app.editTodo.uploadedAttachments.map(a => a.id);

    fetch(`/api/todos/${todoId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title: title,
        content: content,
        attachmentSessionId: app.editTodo.attachmentSessionId,
        orderedAttachmentIds: orderedAttachmentIds,
      })
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '할 일 수정에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return;
      }
      Swal.fire({
        icon: 'success',
        title: '저장되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      app.selectedTodoAttachments = app.editTodo.uploadedAttachments.map(attachment => ({...attachment}));
      app.exitTodoDetailAttachments(true);
      app.loadTodos();
    });
  }
  ,
  completeTodo() {
    const app = this;
    const modal = document.getElementById("todo-details-modal");
    const todoId = modal.getAttribute('data-id');

    fetch(`/api/todos/${todoId}/complete`, {
      method: 'PATCH',
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '할 일 완료 처리에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return null;
      }
      return response.json();
    }).then(data => {
      if (!data) {
        return;
      }
      Swal.fire({
        icon: 'success',
        title: '할 일이 완료되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      app.selectedTodoStatus = data.status;
      app.exitTodoDetailAttachments(true);
      app.loadTodos();
      $('#todo-details-modal').modal('hide');
    });
  }
  ,
  reopenTodo() {
    const app = this;
    const modal = document.getElementById("todo-details-modal");
    const todoId = modal.getAttribute('data-id');

    fetch(`/api/todos/${todoId}/reopen`, {
      method: 'PATCH',
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '할 일 진행중 변경에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return null;
      }
      return response.json();
    }).then(data => {
      if (!data) {
        return;
      }
      Swal.fire({
        icon: 'success',
        title: '할 일이 재오픈 되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      app.selectedTodoStatus = data.status;
      app.exitTodoDetailAttachments(true);
      app.loadTodos();
      $('#todo-details-modal').modal('hide');
    });
  }
  ,
  deleteTodo() {
    const app = this;
    const modal = document.getElementById("todo-details-modal");
    const todoId = modal.getAttribute('data-id');

    Swal.fire({
      icon: 'warning',
      title: '할 일을 삭제할까요?',
      showCancelButton: true,
      confirmButtonText: '삭제',
      cancelButtonText: '취소',
      confirmButtonColor: '#dc3545'
    }).then(result => {
      if (!result.isConfirmed) {
        return;
      }
      fetch(`/api/todos/${todoId}`, {
        method: 'DELETE',
      }).then(response => {
        if (!response.ok) {
          Swal.fire({
            icon: 'error',
            title: '할 일 삭제에 실패했습니다.',
            showConfirmButton: false,
            timer: sweetAlTimer
          });
          return;
        }
        Swal.fire({
          icon: 'success',
          title: '할 일이 삭제되었습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        app.exitTodoDetailAttachments(true);
        app.loadTodos();
        $('#todo-details-modal').modal('hide');
      });
    });
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
}
