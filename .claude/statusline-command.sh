#!/usr/bin/env bash
# Claude Code status line: model, context %, cost, git branch (with color)

input=$(cat)

# ---------------------------------------------------------------------------
# JSON parsing: use jq if available, otherwise fall back to Python
# ---------------------------------------------------------------------------
if command -v jq > /dev/null 2>&1; then
  parse() { echo "$input" | jq -r "$1"; }
else
  # Python fallback — works with Python 3 (standard on modern Windows/WSL)
  parse() {
    local query="$1"
    echo "$input" | python3 -c "
import sys, json
def resolve(obj, path):
    fallback = None
    if '//' in path:
        parts = path.split('//', 1)
        path = parts[0].strip()
        fb = parts[1].strip().strip('\"').strip(\"'\")
        fallback = None if fb == 'empty' else fb
    keys = [k for k in path.lstrip('.').split('.') if k]
    val = obj
    try:
        for k in keys:
            val = val[k]
    except (KeyError, TypeError):
        print(fallback if fallback is not None else '')
        sys.exit(0)
    if val is None:
        print(fallback if fallback is not None else '')
        sys.exit(0)
    print(val)
try:
    data = json.load(sys.stdin)
    resolve(data, sys.argv[1])
except Exception:
    print('')
" "$query" 2>/dev/null
  }
fi

# ---------------------------------------------------------------------------
# Extract fields
# ---------------------------------------------------------------------------
model=$(parse '.model.display_name // "Unknown"')
model_id=$(parse '.model.id // ""')
cwd=$(parse '.workspace.current_dir // ""')
used_pct=$(parse '.context_window.used_percentage // empty')

# Cumulative token counts (session totals)
total_input=$(parse '.context_window.total_input_tokens // 0')
total_output=$(parse '.context_window.total_output_tokens // 0')

# Current context window tokens (for cache fields)
cache_write=$(parse '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(parse '.context_window.current_usage.cache_read_input_tokens // 0')

# ---------------------------------------------------------------------------
# Cost calculation (USD per 1M tokens)
# Pricing by model family:
#   claude-opus-4*       : input $15, output $75, cache_write $18.75, cache_read $1.50
#   claude-sonnet-4*     : input  $3, output $15, cache_write  $3.75, cache_read $0.30
#   claude-haiku-3-5*    : input $0.80, output $4, cache_write $1.00, cache_read $0.08
#   default (sonnet-3-5) : input  $3, output $15, cache_write  $3.75, cache_read $0.30
# ---------------------------------------------------------------------------
cost_str="-"
if command -v python3 > /dev/null 2>&1; then
  cost_str=$(python3 -c "
import sys

model_id = sys.argv[1]
try:
    ti  = float(sys.argv[2])
    to  = float(sys.argv[3])
    cw  = float(sys.argv[4])
    cr  = float(sys.argv[5])
except ValueError:
    ti = to = cw = cr = 0.0

# Select pricing
if 'claude-opus-4' in model_id:
    p_in, p_out, p_cw, p_cr = 15.0, 75.0, 18.75, 1.50
elif 'claude-sonnet-4' in model_id or 'claude-sonnet-3-7' in model_id:
    p_in, p_out, p_cw, p_cr = 3.0, 15.0, 3.75, 0.30
elif 'claude-haiku-3-5' in model_id or 'claude-haiku-3.5' in model_id:
    p_in, p_out, p_cw, p_cr = 0.80, 4.0, 1.00, 0.08
elif 'claude-sonnet-3-5' in model_id or 'claude-sonnet-3.5' in model_id:
    p_in, p_out, p_cw, p_cr = 3.0, 15.0, 3.75, 0.30
else:
    p_in, p_out, p_cw, p_cr = 3.0, 15.0, 3.75, 0.30

cost = (ti * p_in + to * p_out + cw * p_cw + cr * p_cr) / 1_000_000

if cost < 0.001:
    print('<\$0.001')
elif cost < 1.0:
    print(f'\${cost:.3f}')
else:
    print(f'\${cost:.2f}')
" "$model_id" "$total_input" "$total_output" "$cache_write" "$cache_read" 2>/dev/null)
fi

# Context percentage
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  ctx_str="${used_int}%"
else
  ctx_str="-"
fi

# Git branch (skip lock issues gracefully)
git_branch=""
if command -v git > /dev/null 2>&1; then
  branch="$(git -C "${cwd:-.}" branch --show-current 2>/dev/null)"
  if [ -n "$branch" ]; then
    git_branch="$branch"
  fi
fi

# ---------------------------------------------------------------------------
# ANSI colors
# ---------------------------------------------------------------------------
RESET='\033[0m'
BOLD='\033[1m'

C_MODEL='\033[38;5;75m'     # cornflower blue  — model name
C_CTX_OK='\033[38;5;114m'   # green            — context < 70%
C_CTX_WARN='\033[38;5;220m' # yellow           — context 70-89%
C_CTX_HIGH='\033[38;5;203m' # red-orange       — context >= 90%
C_COST='\033[38;5;222m'     # light gold       — cost
C_GIT='\033[38;5;183m'      # lavender         — git branch
C_SEP='\033[38;5;240m'      # dark grey        — separators

# Pick context color based on usage
if [ -n "$used_pct" ] && [ "$used_int" -ge 90 ] 2>/dev/null; then
  C_CTX="$C_CTX_HIGH"
elif [ -n "$used_pct" ] && [ "$used_int" -ge 70 ] 2>/dev/null; then
  C_CTX="$C_CTX_WARN"
else
  C_CTX="$C_CTX_OK"
fi

SEP="${C_SEP} | ${RESET}"

# ---------------------------------------------------------------------------
# Assemble status line
# ---------------------------------------------------------------------------
line="${BOLD}${C_MODEL}${model}${RESET}"
line+="${SEP}${C_CTX}ctx:${ctx_str}${RESET}"
line+="${SEP}${C_COST}cost:${cost_str}${RESET}"

if [ -n "$git_branch" ]; then
  line+="${SEP}${C_GIT}${git_branch}${RESET}"
fi

printf '%b\n' "${line}"
