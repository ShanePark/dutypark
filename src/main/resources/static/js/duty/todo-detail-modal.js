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
      const modal = document.getElementById('todo-details-modal');
      const todoId = modal ? modal.getAttribute('data-id') : null;

      const uploader = await todoAttachmentHelpers.createUppyUploader({
        state: app.editTodo,
        fileInputId: 'todo-detail-attachment-input',
        createSessionFn: () => todoAttachmentHelpers.createSession(todoId),
        showAlertFn: todoAttachmentHelpers.showAlert,
        handleXhrErrorFn: todoAttachmentHelpers.handleXhrError,
        normalizeDtoFn: todoAttachmentHelpers.normalizeAttachmentDto,
        resolveDtoUrlFn: todoAttachmentHelpers.resolveDownloadUrl,
        startTickerFn: () => this.todoDetailStartAttachmentUploadTicker(),
        stopTickerFn: () => this.todoDetailStopAttachmentUploadTicker(),
        validation: todoAttachmentHelpers.validationConfig,
        vueApp: app,
        useUniqueFileId: true,
      });

      app.todoDetailUppyInstance = uploader.uppyInstance;
      app.todoDetailFileInputListener = uploader.fileInputListener;
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
