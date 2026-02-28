#!/usr/bin/env bash
# Claude Code Stop Hook - 대기 상태 Slack 알림
# Claude가 작업을 완료하고 입력을 기다릴 때 실행됨

# Webhook URL이 없으면 조용히 종료
if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  exit 0
fi

# stdin에서 이벤트 JSON 읽기
INPUT=$(cat)

# Python3으로 JSON 파싱 및 Slack 페이로드 생성
PAYLOAD=$(HOOK_INPUT="$INPUT" python3 - <<'PYEOF'
import sys, json, os

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except Exception:
    sys.exit(0)

cwd = data.get("cwd", "")
session_id = data.get("session_id", "")

# 프로젝트명 추출
if cwd:
    import pathlib
    project = pathlib.PurePath(cwd).name or "unknown"
else:
    project = "unknown"

session_short = (session_id[:8] + "...") if len(session_id) > 8 else session_id or "unknown"

blocks = [
    {
        "type": "header",
        "text": {"type": "plain_text", "text": "✅ Claude Code - 작업 완료", "emoji": True}
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
        "text": {"type": "mrkdwn", "text": "*상태:* 입력을 기다리고 있습니다"}
    }
]

payload = {
    "attachments": [
        {
            "color": "#4CAF50",
            "fallback": f"[{project}] ✅ Claude Code - 작업 완료",
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

# Slack Webhook 전송
curl -sf \
  -X POST \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  --max-time 8 \
  "$SLACK_WEBHOOK_URL" > /dev/null 2>&1 || true

exit 0
