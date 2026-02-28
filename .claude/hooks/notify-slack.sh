#!/usr/bin/env bash
# Claude Code Hooks - Slack 알림 스크립트
# Notification 이벤트(permission_prompt, idle_prompt)를 받아 Slack으로 전송

# Webhook URL이 없으면 조용히 종료
if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  exit 0
fi

# stdin에서 이벤트 JSON 읽기
INPUT=$(cat)

# Python3으로 JSON 파싱 및 Slack 페이로드 생성 (jq 미설치 환경 대응)
PAYLOAD=$(HOOK_INPUT="$INPUT" python3 - <<'PYEOF'
import sys, json, os

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except Exception:
    sys.exit(0)

notification_type = data.get("notification_type", "")
message = data.get("message", "")
cwd = data.get("cwd", "")
session_id = data.get("session_id", "")

# 프로젝트명 추출
if cwd:
    import pathlib
    project = pathlib.PurePath(cwd).name or "unknown"
else:
    project = "unknown"

session_short = (session_id[:8] + "...") if len(session_id) > 8 else session_id or "unknown"

# 알림 유형별 설정
if notification_type == "permission_prompt":
    color = "#FF9800"
    header = "🔒 Claude Code - 권한 요청"
    status_text = "도구 실행 승인이 필요합니다"
elif notification_type == "idle_prompt":
    color = "#4CAF50"
    header = "✅ Claude Code - 작업 완료"
    status_text = "입력을 기다리고 있습니다"
else:
    sys.exit(0)

# Block Kit 페이로드 구성
blocks = [
    {
        "type": "header",
        "text": {"type": "plain_text", "text": header, "emoji": True}
    },
    {
        "type": "section",
        "fields": [
            {"type": "mrkdwn", "text": f"*프로젝트:*\n`{project}`"},
            {"type": "mrkdwn", "text": f"*세션:*\n`{session_short}`"}
        ]
    },
    {
        "type": "section",
        "text": {"type": "mrkdwn", "text": f"*상태:* {status_text}"}
    }
]

# 메시지가 있으면 컨텍스트로 추가
if message:
    truncated = message[:200] + ("..." if len(message) > 200 else "")
    blocks.append({
        "type": "context",
        "elements": [{"type": "mrkdwn", "text": truncated}]
    })

payload = {
    "attachments": [
        {
            "color": color,
            "fallback": f"[{project}] {header}",
            "blocks": blocks
        }
    ]
}

print(json.dumps(payload))
PYEOF
) || exit 0

# 페이로드가 비어있으면 종료
if [[ -z "$PAYLOAD" ]]; then
  exit 0
fi

# Slack Webhook 전송 (실패해도 Claude Code에 영향 없도록)
curl -sf \
  -X POST \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  --max-time 8 \
  "$SLACK_WEBHOOK_URL" > /dev/null 2>&1 || true

exit 0
