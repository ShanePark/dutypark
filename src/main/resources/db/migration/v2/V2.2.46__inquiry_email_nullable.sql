-- 로그인 회원은 앱 안에서 답변을 읽으므로 회신 이메일이 없을 수 있다.
-- (소셜 로그인 계정은 이메일 자체가 없다.) 비회원 문의는 여전히 이메일이 필수다.
ALTER TABLE inquiry
    MODIFY COLUMN email VARCHAR(255) NULL;
