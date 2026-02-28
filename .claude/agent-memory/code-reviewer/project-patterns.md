# 프로젝트 패턴 및 아키텍처

## Claude Code Hooks 설계 원칙
- 모든 훅은 Claude Code 동작에 영향을 주지 않아야 함
- async:true + exit 0 반환으로 fire-and-forget 구현
- 실패는 조용히 무시 (|| true, || exit 0)

## notify-slack.sh 패턴
- jq 대신 Python3 heredoc 방식으로 JSON 처리 (크로스플랫폼 대응)
- stdin -> 환경변수(HOOK_INPUT) -> python3 방식 (ARG_MAX 한도 주의 필요)
- Block Kit attachments 구조: color + fallback + blocks 조합
- curl: -sf 플래그 (silent + fail-on-http-error)
- 타임아웃: curl 8초, 훅 전체 10초 (Python 기동 시간 고려)

## settings.local.json 구조
- env: 환경변수 주입 (SLACK_WEBHOOK_URL 등)
- permissions.allow: Bash 명령어 허용 목록 (Bash(git:*) 등)
- hooks: 이벤트별 훅 설정
- enabledMcpjsonServers: context7, playwright 활성화

## Windows 환경 특이사항
- Git Bash에서 $CLAUDE_PROJECT_DIR은 /c/cwork/... 형태로 확장됨
- bash 스크립트 경로에서 Windows 스타일 경로(C:\...) 사용 시 문제 발생
- 상대 경로 사용이 더 안전한 대안
