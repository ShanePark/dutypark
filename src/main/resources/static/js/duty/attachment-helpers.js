const AttachmentHelpers = window.AttachmentHelpers || (() => {
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
    },
    duplicateFileMessage(filename) {
      const target = filename ? `${filename} 파일은` : '이 파일은';
      return `${target} 이미 추가되어 있습니다.`;
    }
  };

  const normalizeAttachmentDto = (dto = {}) => ({
    id: dto.id,
    name: dto.originalFilename,
    originalFilename: dto.originalFilename,
    contentType: dto.contentType,
    size: dto.size,
    thumbnailUrl: dto.thumbnailUrl,
    downloadUrl: dto.id ? `/api/attachments/${dto.id}/download` : null,
    isImage: dto.contentType ? dto.contentType.startsWith('image/') : false,
    hasThumbnail: dto.hasThumbnail,
    orderIndex: dto.orderIndex,
    createdAt: dto.createdAt,
    createdBy: dto.createdBy,
    previewUrl: dto.previewUrl || null,
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

  const attachmentIconClass = (attachment) => {
    if (!attachment) {
      return 'bi-file-earmark';
    }
    const filename = (attachment.originalFilename || attachment.name || '').toLowerCase();
    const ext = getFileExtension(filename);
    if (ext && ATTACHMENT_ICON_BY_EXTENSION[ext]) {
      return ATTACHMENT_ICON_BY_EXTENSION[ext];
    }
    const contentType = attachment.contentType || attachment.mimeType;
    if (contentType && ATTACHMENT_ICON_BY_CONTENT_TYPE[contentType]) {
      return ATTACHMENT_ICON_BY_CONTENT_TYPE[contentType];
    }
    return attachment.isImage ? 'bi-file-earmark-image' : 'bi-file-earmark';
  };

  const showAlert = (message, options = {}) => {
    if (!message) {
      return;
    }
    const {
      icon = 'error',
      showConfirmButton = false,
      confirmButtonText = '확인',
      timer = sweetAlTimer,
    } = options;
    const payload = {
      icon,
      title: message,
      showConfirmButton,
      confirmButtonText,
    };
    if (timer === null) {
      payload.timer = undefined;
    } else {
      payload.timer = timer;
    }
    Swal.fire(payload);
  };

  const validateFile = (file, options = {}) => {
    const config = options.validationConfig || validationConfig;
    if (!file) {
      return {valid: false, message: '업로드할 파일을 찾지 못했습니다.'};
    }
    if (file.size > config.maxFileSizeBytes) {
      return {
        valid: false,
        message: config.tooLargeMessage(file.name)
      };
    }
    return {valid: true};
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

  const resolveDownloadUrl = (attachment, options = {}) => {
    if (!attachment) {
      return null;
    }
    const baseUrl = attachment.downloadUrl || (attachment.id ? `/api/attachments/${attachment.id}/download` : null);
    if (!baseUrl) {
      return null;
    }
    const {inline = false} = options;
    if (!inline) {
      return baseUrl;
    }
    const separator = baseUrl.includes('?') ? '&' : '?';
    return `${baseUrl}${separator}inline=true`;
  };

  const openViewer = (attachment, options = {}) => {
    if (!attachment) {
      return;
    }
    const {
      onClose = null,
      missingMessage = '이미지를 불러오지 못했습니다.',
      swalOptions = {},
    } = options;
    const fileName = attachment.originalFilename || attachment.name || '이미지';
    let imageSource = attachment.previewUrl;
    if (!imageSource) {
      const baseDownloadUrl = resolveDownloadUrl(attachment, {inline: true});
      if (baseDownloadUrl) {
        imageSource = baseDownloadUrl;
      }
    }
    if (!imageSource && attachment.thumbnailUrl) {
      imageSource = attachment.thumbnailUrl;
    }
    if (!imageSource) {
      showAlert(missingMessage, swalOptions);
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
      ...swalOptions,
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
      },
      didClose: () => {
        if (typeof onClose === 'function') {
          onClose();
        }
      }
    });
  };

  const handleResponseError = async (response, fallbackMessage, options = {}) => {
    const {fileName, validation = validationConfig, alertOptions} = options;
    let message = fallbackMessage;
    if (response) {
      let body = null;
      try {
        body = await response.clone().json();
      } catch {
        body = null;
      }
      if (response.status === 413) {
        message = body?.message || validation.tooLargeMessage(fileName);
      } else if (response.status === 400 && body?.code === 'ATTACHMENT_EXTENSION_BLOCKED') {
        if (fileName) {
          message = validation.blockedExtensionMessage(fileName);
        } else if (body?.message) {
          message = body.message;
        }
      } else if (body?.message) {
        message = body.message;
      }
    }
    showAlert(message, alertOptions);
    throw new Error(message);
  };

  const handleXhrError = (xhr, file, options = {}) => {
    const {validation = validationConfig, alertOptions} = options;
    const fileName = file?.name;
    if (xhr.status === 0) {
      showAlert('네트워크 오류가 발생했습니다. 잠시 후 다시 시도해주세요.', alertOptions);
      return new Error('Network error during attachment upload');
    }
    if (xhr.status === 413) {
      const message = xhr.response?.message || validation.tooLargeMessage(fileName);
      showAlert(message, alertOptions);
      return new Error(message);
    }
    if (xhr.status === 400 && xhr.response?.code === 'ATTACHMENT_EXTENSION_BLOCKED' && fileName) {
      const message = validation.blockedExtensionMessage(fileName);
      showAlert(message, alertOptions);
      return new Error(message);
    }
    const message = xhr.response?.message || '파일 업로드에 실패했습니다.';
    showAlert(message, alertOptions);
    return new Error(message);
  };

  const fetchJson = async (url, options, fallbackMessage, alertOptions) => {
    const response = await fetch(url, options);
    if (!response.ok) {
      await handleResponseError(response, fallbackMessage, {alertOptions});
    }
    return response.json();
  };

  const createSession = ({contextType, targetContextId = null}) => fetchJson('/api/attachments/sessions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      contextType,
      targetContextId
    })
  }, '파일 업로드 세션 생성에 실패했습니다.');

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

  const listAttachments = async ({contextType, contextId}) => {
    const response = await fetch(`/api/attachments?contextType=${contextType}&contextId=${contextId}`, {
      method: 'GET'
    });
    if (!response.ok) {
      await handleResponseError(response, '첨부파일을 불러오지 못했습니다.');
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
    formatBytes,
    openViewer,
    resolveDownloadUrl,
    handleResponseError,
    handleXhrError,
    createSession,
    deleteSession,
    listAttachments,
  };
})();

window.AttachmentHelpers = AttachmentHelpers;
