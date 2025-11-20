const scheduleAttachmentHelpers = (() => {
  const base = window.AttachmentHelpers;
  const alertOptions = {showConfirmButton: true, confirmButtonText: '확인', timer: null};

  const showAlert = (message) => base.showAlert(message, alertOptions);

  const handleResponseError = async (response, fallbackMessage, options = {}) => {
    const {fileName} = options;
    await base.handleResponseError(response, fallbackMessage, {
      fileName,
      alertOptions
    });
  };

  const handleXhrError = (xhr, file) => base.handleXhrError(xhr, file, {alertOptions});

  const createSession = async (targetContextId = null) => base.createSession({
    contextType: 'SCHEDULE',
    targetContextId
  });

  return {
    validationConfig: base.validationConfig,
    normalizeAttachmentDto: base.normalizeAttachmentDto,
    validateFile: (file) => base.validateFile(file),
    showAlert,
    buildUploadProgressPayload: base.buildUploadProgressPayload,
    handleResponseError,
    handleXhrError,
    resolveDownloadUrl: base.resolveDownloadUrl,
    createSession,
    createUppyUploader: base.createUppyUploader,
    formatBytes: base.formatBytes,
    openViewer: base.openViewer,
    attachmentIconClass: base.attachmentIconClass,
    setupDropZone: base.setupDropZone,
    cleanupDropZone: base.cleanupDropZone,
  };
})();

const detailViewMethods = {
  async scheduleCreateMode() {
    this.resetCreateSchedule();
    this.isCreateScheduleMode = true;
    await this.$nextTick();
    await this.initializeAttachmentUploader();
  }
  ,
  cancelCreateSchedule() {
    if (this.createSchedule.attachmentSessionId) {
      fetch(`/api/attachments/sessions/${this.createSchedule.attachmentSessionId}`, {
        method: 'DELETE'
      }).catch(error => {
        console.warn('Failed to cleanup attachment session:', error);
      });
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

    if (app.dropZoneListeners) {
      scheduleAttachmentHelpers.cleanupDropZone('label[for="schedule-attachment-input"]', app.dropZoneListeners);
      app.dropZoneListeners = null;
    }

    try {
      const uploader = await scheduleAttachmentHelpers.createUppyUploader({
        state: app.createSchedule,
        fileInputId: 'schedule-attachment-input',
        createSessionFn: scheduleAttachmentHelpers.createSession,
        showAlertFn: scheduleAttachmentHelpers.showAlert,
        handleXhrErrorFn: scheduleAttachmentHelpers.handleXhrError,
        normalizeDtoFn: scheduleAttachmentHelpers.normalizeAttachmentDto,
        resolveDtoUrlFn: scheduleAttachmentHelpers.resolveDownloadUrl,
        startTickerFn: () => app.startAttachmentUploadTicker(),
        stopTickerFn: () => app.stopAttachmentUploadTicker(),
        validation: scheduleAttachmentHelpers.validationConfig,
        vueApp: app,
        useUniqueFileId: false,
      });

      app.uppyInstance = uploader.uppyInstance;
      app.fileInputListener = uploader.fileInputListener;

      if (app.uppyInstance) {
        app.dropZoneListeners = scheduleAttachmentHelpers.setupDropZone('label[for="schedule-attachment-input"]', app.uppyInstance);
      }
    } catch (error) {
      console.error('Failed to initialize attachment uploader:', error);
      scheduleAttachmentHelpers.showAlert('첨부파일 업로드 기능을 초기화하지 못했습니다.');
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

    if (app.dropZoneListeners) {
      scheduleAttachmentHelpers.cleanupDropZone('label[for="schedule-attachment-input"]', app.dropZoneListeners);
      app.dropZoneListeners = null;
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
    return scheduleAttachmentHelpers.openViewer(attachment, {
      onClose,
      missingMessage: '이미지를 불러오지 못했습니다.'
    });
  }
  ,
  attachmentIconClass(attachment) {
    return scheduleAttachmentHelpers.attachmentIconClass(attachment);
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
    return scheduleAttachmentHelpers.formatBytes(bytes);
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
