# 보안 이슈 기록

## [2026-02-28] .gitignore 미설정 - 치명적

### 상황
- .gitignore 파일이 프로젝트 루트에 존재하지 않음
- .claude/settings.local.json이 git 추적 대상
- settings.local.json에 SLACK_WEBHOOK_URL 환경변수가 정의됨

### 위험
- 실제 Webhook URL 입력 후 커밋 시 git 히스토리에 영구 노출
- Slack Webhook URL은 인증 토큰 역할 - 노출 시 채널 스팸 가능

### 권고 조치
```bash
git rm --cached .claude/settings.local.json  # 캐시 추적 제거
echo ".claude/settings.local.json" >> .gitignore
git add .gitignore && git commit -m "보안: settings.local.json git 추적 제외"
```

### 현재 상태
- 미해결 (플레이스홀더 URL이 있는 상태로 추적 중으로 추정)
