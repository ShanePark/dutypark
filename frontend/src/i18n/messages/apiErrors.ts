export const apiErrorMessagesEn = {
  auth: {
    required: 'Login is required.',
    unauthorized: 'Unauthorized.',
    login: {
      failed: 'Email or password is incorrect.',
      rateLimited: 'Too many login attempts. Please try again later.',
    },
    password: {
      memberNotFound: 'Account does not exist.',
      currentMismatch: 'Current password does not match.',
      changeUnauthorized: 'You are not authorized to change this password.',
      changed: 'Password changed.',
    },
    refresh: {
      invalid: 'Invalid refresh token.',
      expired: 'Refresh token has expired.',
    },
    token: {
      memberNotFound: 'Account does not exist.',
    },
    impersonation: {
      alreadyImpersonating: 'You are already impersonating another account.',
      managerNotFound: 'Manager account could not be found.',
      targetNotFound: 'Target account could not be found.',
      forbidden: 'You do not have permission to manage this account.',
      failed: 'Failed to switch accounts.',
    },
    restore: {
      notImpersonating: 'You are not currently impersonating another account.',
      originalMissing: 'Original account information is missing.',
      originalNotFound: 'Original account could not be found.',
      failed: 'Failed to restore the original account.',
    },
    oauth: {
      callbackUrl: {
        required: 'Callback URL is required.',
      },
    },
  },
  common: {
    notFound: 'Resource not found.',
    badRequest: 'Bad request.',
    validation: {
      failed: 'Please check the request fields.',
    },
    rateLimit: {
      exceeded: 'Too many requests. Please try again later.',
    },
  },
  member: {
    notFound: 'Member not found.',
    visibility: {
      update: {
        forbidden: 'You cannot update another member\'s visibility.',
      },
    },
    auxiliary: {
      name: {
        required: 'Name is required.',
      },
    },
  },
  dutyType: {
    name: {
      required: 'Duty name is required.',
      length: 'Duty names must be between 1 and 10 characters.',
      duplicate: 'A duty type with the same name already exists.',
    },
    color: {
      invalid: 'Invalid color format.',
    },
  },
  team: {
    name: {
      required: 'Team name is required.',
      length: 'Team names must be between 2 and 20 characters.',
    },
    description: {
      length: 'Descriptions must be 50 characters or fewer.',
    },
    dutyType: {
      sameTeam: {
        required: 'Duty types must belong to the same team.',
      },
    },
  },
  sso: {
    uuid: {
      required: 'Sign-up session information is required.',
      invalid: 'The sign-up session is invalid or has expired.',
    },
    username: {
      required: 'Username is required.',
      length: 'Usernames must be between 1 and 10 characters.',
    },
  },
  dday: {
    title: {
      required: 'D-Day title is required.',
      length: 'D-Day titles must be between 1 and 30 characters.',
    },
  },
  dutyBatch: {
    unknown: 'Failed to upload the duty schedule.',
    nameNotFound: 'Could not find the member name in the uploaded file.',
    multipleNameFound: 'Multiple matching names were found in the uploaded file.',
    notSupportedFile: 'This file format is not supported. Supported formats: {supportedFile}',
    dutyTypeNotSingle: 'The team must have exactly one duty type to use batch upload.',
    yearMonthNotMatch: 'The uploaded file month does not match the selected schedule month ({year}-{month}).',
    template: {
      required: 'Select a batch upload template first.',
    },
    member: {
      teamRequired: 'The account must belong to a team to use batch upload.',
    },
  },
  attachment: {
    extension: {
      blocked: 'This file extension is not allowed.',
    },
    size: {
      exceeded: 'The file is too large.',
    },
  },
  todo: {
    reorder: {
      orderedIds: {
        required: 'The reordered to-do ID list is required.',
      },
    },
  },
} as const

export const apiErrorMessagesKo = {
  auth: {
    required: '로그인이 필요합니다.',
    unauthorized: '인증이 필요합니다.',
    login: {
      failed: '이메일 또는 비밀번호가 올바르지 않습니다.',
      rateLimited: '로그인 시도 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요.',
    },
    password: {
      memberNotFound: '존재하지 않는 계정입니다.',
      currentMismatch: '현재 비밀번호가 일치하지 않습니다.',
      changeUnauthorized: '이 비밀번호를 변경할 권한이 없습니다.',
      changed: '비밀번호가 변경되었습니다.',
    },
    refresh: {
      invalid: '유효하지 않은 리프레시 토큰입니다.',
      expired: '리프레시 토큰이 만료되었습니다.',
    },
    token: {
      memberNotFound: '존재하지 않는 계정입니다.',
    },
    impersonation: {
      alreadyImpersonating: '이미 다른 계정으로 전환된 상태입니다.',
      managerNotFound: '관리자 계정을 찾을 수 없습니다.',
      targetNotFound: '대상 계정을 찾을 수 없습니다.',
      forbidden: '관리 권한이 없습니다.',
      failed: '계정 전환에 실패했습니다.',
    },
    restore: {
      notImpersonating: '전환된 계정 상태가 아닙니다.',
      originalMissing: '원래 계정 정보가 없습니다.',
      originalNotFound: '원래 계정을 찾을 수 없습니다.',
      failed: '계정 복원에 실패했습니다.',
    },
    oauth: {
      callbackUrl: {
        required: '콜백 URL 정보가 필요합니다.',
      },
    },
  },
  common: {
    notFound: '리소스를 찾을 수 없습니다.',
    badRequest: '잘못된 요청입니다.',
    validation: {
      failed: '요청 값을 다시 확인해 주세요.',
    },
    rateLimit: {
      exceeded: '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
    },
  },
  member: {
    notFound: '회원을 찾을 수 없습니다.',
    visibility: {
      update: {
        forbidden: '다른 회원의 공개 범위는 변경할 수 없습니다.',
      },
    },
    auxiliary: {
      name: {
        required: '이름은 필수입니다.',
      },
    },
  },
  dutyType: {
    name: {
      required: '근무명은 필수입니다.',
      length: '근무명은 1자 이상 10자 이하로 입력해주세요.',
      duplicate: '동일한 이름의 근무 유형이 이미 존재합니다.',
    },
    color: {
      invalid: '올바른 색상 형식이 아닙니다.',
    },
  },
  team: {
    name: {
      required: '팀 이름은 필수입니다.',
      length: '팀 이름은 2자 이상 20자 이하로 입력해주세요.',
    },
    description: {
      length: '설명은 50자 이하로 입력해주세요.',
    },
    dutyType: {
      sameTeam: {
        required: '근무 유형은 같은 팀에 속해 있어야 합니다.',
      },
    },
  },
  sso: {
    uuid: {
      required: '회원가입 세션 정보가 필요합니다.',
      invalid: '회원가입 세션이 유효하지 않거나 만료되었습니다.',
    },
    username: {
      required: '사용자명은 필수입니다.',
      length: '사용자명은 1자 이상 10자 이하로 입력해주세요.',
    },
  },
  dday: {
    title: {
      required: 'D-DAY 제목은 필수입니다.',
      length: 'D-DAY 제목은 1자 이상 30자 이하로 입력해주세요.',
    },
  },
  dutyBatch: {
    unknown: '시간표 업로드에 실패했습니다.',
    nameNotFound: '업로드한 파일에서 사용자의 이름을 찾을 수 없습니다.',
    multipleNameFound: '업로드한 파일에서 같은 이름의 사용자가 여러 명 발견되었습니다.',
    notSupportedFile: '지원하지 않는 파일 형식입니다. 지원 형식: {supportedFile}',
    dutyTypeNotSingle: '일괄 업로드를 사용하려면 팀의 근무 유형이 정확히 1개여야 합니다.',
    yearMonthNotMatch: '업로드한 파일의 연월이 현재 설정 중인 시간표({year}년 {month}월)와 일치하지 않습니다.',
    template: {
      required: '먼저 일괄 업로드 템플릿을 선택해주세요.',
    },
    member: {
      teamRequired: '시간표 일괄 업로드를 사용하려면 팀에 속한 계정이어야 합니다.',
    },
  },
  attachment: {
    extension: {
      blocked: '허용되지 않는 파일 확장자입니다.',
    },
    size: {
      exceeded: '파일 크기가 너무 큽니다.',
    },
  },
  todo: {
    reorder: {
      orderedIds: {
        required: '같은 상태에서 순서를 바꾸려면 정렬된 할 일 ID 목록이 필요합니다.',
      },
    },
  },
} as const

export const apiErrorMessagesJa = {
  auth: {
    required: 'ログインが必要です。',
    unauthorized: '認証が必要です。',
    login: {
      failed: 'メールアドレスまたはパスワードが正しくありません。',
      rateLimited: 'ログイン試行回数が多すぎます。しばらくしてから再試行してください。',
    },
    password: {
      memberNotFound: 'アカウントが存在しません。',
      currentMismatch: '現在のパスワードが一致しません。',
      changeUnauthorized: 'このパスワードを変更する権限がありません。',
      changed: 'パスワードが変更されました。',
    },
    refresh: {
      invalid: '無効なリフレッシュトークンです。',
      expired: 'リフレッシュトークンの有効期限が切れています。',
    },
    token: {
      memberNotFound: 'アカウントが存在しません。',
    },
    impersonation: {
      alreadyImpersonating: 'すでに別のアカウントに切り替え中です。',
      managerNotFound: '管理者アカウントが見つかりません。',
      targetNotFound: '対象アカウントが見つかりません。',
      forbidden: 'このアカウントを管理する権限がありません。',
      failed: 'アカウント切り替えに失敗しました。',
    },
    restore: {
      notImpersonating: '現在はアカウント切り替え状態ではありません。',
      originalMissing: '元のアカウント情報がありません。',
      originalNotFound: '元のアカウントが見つかりません。',
      failed: '元のアカウントへ戻れませんでした。',
    },
    oauth: {
      callbackUrl: {
        required: 'コールバックURLが必要です。',
      },
    },
  },
  common: {
    notFound: 'リソースが見つかりません。',
    badRequest: '不正なリクエストです。',
    validation: {
      failed: 'リクエスト内容を確認してください。',
    },
    rateLimit: {
      exceeded: 'リクエストが多すぎます。しばらくしてから再試行してください。',
    },
  },
  member: {
    notFound: '会員が見つかりません。',
    visibility: {
      update: {
        forbidden: '他の会員の公開範囲は変更できません。',
      },
    },
    auxiliary: {
      name: {
        required: '名前は必須です。',
      },
    },
  },
  dutyType: {
    name: {
      required: '勤務名は必須です。',
      length: '勤務名は1文字以上10文字以下で入力してください。',
      duplicate: '同じ名前の勤務タイプがすでに存在します。',
    },
    color: {
      invalid: '色の形式が正しくありません。',
    },
  },
  team: {
    name: {
      required: 'チーム名は必須です。',
      length: 'チーム名は2文字以上20文字以下で入力してください。',
    },
    description: {
      length: '説明は50文字以内で入力してください。',
    },
    dutyType: {
      sameTeam: {
        required: '勤務タイプは同じチームに属している必要があります。',
      },
    },
  },
  sso: {
    uuid: {
      required: '会員登録セッション情報が必要です。',
      invalid: '会員登録セッションが無効か、期限切れです。',
    },
    username: {
      required: 'ユーザー名は必須です。',
      length: 'ユーザー名は1文字以上10文字以下で入力してください。',
    },
  },
  dday: {
    title: {
      required: 'D-Dayのタイトルは必須です。',
      length: 'D-Dayのタイトルは1文字以上30文字以下で入力してください。',
    },
  },
  dutyBatch: {
    unknown: '勤務表のアップロードに失敗しました。',
    nameNotFound: 'アップロードしたファイルから利用者名を見つけられませんでした。',
    multipleNameFound: 'アップロードしたファイルで同じ名前の利用者が複数見つかりました。',
    notSupportedFile: 'このファイル形式には対応していません。対応形式: {supportedFile}',
    dutyTypeNotSingle: '一括アップロードを使うには、チームの勤務タイプがちょうど1つ必要です。',
    yearMonthNotMatch: 'アップロードしたファイルの年月が選択した勤務表年月（{year}-{month}）と一致しません。',
    template: {
      required: '先に一括アップロードテンプレートを選択してください。',
    },
    member: {
      teamRequired: '勤務表の一括アップロードを使うには、チーム所属アカウントである必要があります。',
    },
  },
  attachment: {
    extension: {
      blocked: '許可されていないファイル拡張子です。',
    },
    size: {
      exceeded: 'ファイルサイズが大きすぎます。',
    },
  },
  todo: {
    reorder: {
      orderedIds: {
        required: '同じ状態で並び替えるには、並び替え後のやることID一覧が必要です。',
      },
    },
  },
} as const
