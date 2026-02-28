# 코드 리뷰어 에이전트 메모리

## 프로젝트 개요
- 프로젝트: claude-mastery (Claude Code 학습/실습용 저장소)
- 플랫폼: Windows 10, Git Bash/WSL 혼용 환경
- 언어 규칙: 응답/주석/커밋 한국어, 변수명/함수명 영어

## 확인된 보안 이슈
- .gitignore 파일이 존재하지 않음 (2026-02-28 확인)
- settings.local.json이 git에 추적 중일 가능성 높음
- 자세한 내용: security-issues.md 참조

## 프로젝트 패턴 및 컨벤션
- Claude Code Hooks: async:true + exit 0으로 Claude에 영향 없는 설계 원칙 준수
- jq 의존성 없이 Python3 heredoc으로 JSON 처리하는 패턴 사용
- settings.local.json: 로컬 전용 설정 (Webhook URL, 권한 등)
- 자세한 내용: project-patterns.md 참조

## 자주 발생하는 이슈 유형
- bash 스크립트에서 환경변수로 대용량 데이터 전달 시 ARG_MAX 한도 문제
- curl --data vs --data-raw 구분 미흡 (@ 파일 경로 해석 차이)
- Windows 경로 처리: $CLAUDE_PROJECT_DIR이 C:\... 형태일 경우 bash 비호환
