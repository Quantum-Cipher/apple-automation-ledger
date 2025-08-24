#!/bin/bash
set -euo pipefail
LOG_DIR=~/Automation/logs
OUT=~/Automation/logs/ledger_merkle.json
mkdir -p "$LOG_DIR"
sha_files=()
while IFS= read -r -d '' f; do
  sha=$(shasum -a 256 "$f" | awk '{print $1}')
  sha_files+=("$sha")
done < <(find "$LOG_DIR" -type f -name "*.log" -print0 2>/dev/null)
if [[ ${#sha_files[@]} -eq 0 ]]; then
  echo '{"error":"no log files"}' > "$OUT"; echo "$OUT"; exit 0
fi
# build merkle
level=("${sha_files[@]}")
while ((${#level[@]} > 1)); do
  next=()
  for ((i=0; i<${#level[@]}; i+=2)); do
    left="${level[i]}"; right="${level[i+1]:-${level[i]}}"
    next+=( "$(printf "%s%s" "$left" "$right" | xxd -r -p | shasum -a 256 | awk '{print $1}')" )
  done
  level=("${next[@]}")
done
root="${level[0]}"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
host=$(scutil --get ComputerName 2>/dev/null || hostname)
jq -n --arg root "$root" --arg time "$timestamp" --arg host "$host" \
  '{merkle_root:$root, algo:"sha256", timestamp:$time, host:$host}' > "$OUT" 2>/dev/null \
  || echo "{\"merkle_root\":\"$root\",\"algo\":\"sha256\",\"timestamp\":\"$timestamp\",\"host\":\"$host\"}" > "$OUT"
echo "$OUT"
