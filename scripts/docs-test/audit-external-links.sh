#!/usr/bin/env bash
# audit-external-links.sh — Re-run the Phase 01 / Cycle 4 external link audit
#
# Usage:
#   scripts/docs-test/audit-external-links.sh [--output-dir DIR]
#
# Outputs:
#   <output-dir>/external-links-<phase>.json
#   <output-dir>/external-links-<phase>.txt  (summary)
#
# Defaults:
#   --output-dir  _internal/.plan/audits
#   --phase       phase-01
#
# The script is used in Phase 08 (re-audit) and Phase 10 (final audit).
# Set AUDIT_PHASE env var to change the output file suffix.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
DOCS_DIR="$REPO_ROOT/src/content/docs"

OUTPUT_DIR="$REPO_ROOT/_internal/.plan/audits"
PHASE="${AUDIT_PHASE:-phase-01}"
UA="Mozilla/5.0 (compatible; FraiseQLDocsLinkAudit/1.0)"
MAX_TIME=10
PARALLEL=8

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --phase)      PHASE="$2"; shift 2 ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

RAW_URLS="/tmp/link-audit-raw-$$.txt"
CLEAN_URLS="/tmp/link-audit-clean-$$.txt"
AUDIT_OUT="/tmp/link-audit-results-$$.txt"
trap 'rm -f "$RAW_URLS" "$CLEAN_URLS" "$AUDIT_OUT"' EXIT

echo "[1/4] Extracting external URLs from $DOCS_DIR ..."
grep -rEHn 'https?://[a-zA-Z0-9._~:/?#@!$&'"'"'*+,;=%-]+' "$DOCS_DIR" > "$RAW_URLS" 2>/dev/null || true

echo "[2/4] Filtering placeholder/internal-service URLs ..."
python3 - "$RAW_URLS" "$CLEAN_URLS" << 'PYEOF'
import re
import sys
import json

raw_path = sys.argv[1]
clean_path = sys.argv[2]

url_pattern = re.compile(r'(https?://[^\s\)\]"\'<>{}|\\]+)')

# Patterns that indicate a URL is a placeholder or internal service name
skip_patterns = [
    r'example\.com', r'your-domain\.com', r'your-app\.com',
    r'localhost[:/]', r'127\.0\.0\.1[:/]',
    r'api\.example\.com', r'app\.example\.com', r'www\.example\.com',
    r'^http://localhost', r'^http://127\.0\.0\.1',
    r'^http://[a-z-]+(:[0-9]+)?(/|$)',  # docker service names
    r'^http://[a-z]',  # all plain http (non-https) service names
    r'^https://\$',   # shell variables
    r'^https://$',    # empty
    r'^https://\.\.\.',  # placeholder dots
    r'your-app/', r'your-domain\.', r'your-tenant\.',
    r'your-auth-provider', r'your-logto', r'your-ory',
    r'YOUR_', r'-kv\.vault\.azure\.net',
    r'my-bucket\.', r'myaccount\.blob\.core\.windows\.net',
    r'myapp\.com', r'\$REGISTRY_NAME', r'email-svc/',
    r'events/ingest$', r'payments\.internal', r'telemetry\.googleapis\.com',
    r'token\.actions\.githubusercontent\.com', r'pub-xxxx',
    r's3\.gra\.', r's3\.fr-par\.',
    r'storage\.googleapis\.com/my-bucket',
    r'my-bucket\.s3\.amazonaws\.com', r'bucket\.s3\.amazonaws\.com',
    r'^https://fraiseql[^\.com]',
]

url_to_sites = {}

with open(raw_path) as f:
    for line in f:
        parts = line.split(':', 2)
        if len(parts) < 3:
            continue
        filepath = parts[0]
        try:
            linenum = int(parts[1])
        except ValueError:
            continue
        content = parts[2]

        for url in url_pattern.findall(content):
            url = url.rstrip('.,;:)]\'"')
            is_skip = any(re.search(p, url) for p in skip_patterns)
            if not is_skip:
                if url not in url_to_sites:
                    url_to_sites[url] = []
                site = {"file": filepath, "line": linenum}
                if site not in url_to_sites[url]:
                    url_to_sites[url].append(site)

with open(clean_path, 'w') as f:
    json.dump(url_to_sites, f)

print(f"  {len(url_to_sites)} unique auditable URLs extracted")
PYEOF

echo "[3/4] Auditing URLs (parallel=$PARALLEL, max-time=${MAX_TIME}s) ..."

# Read URLs and audit each one
python3 -c "
import json, sys
with open('$CLEAN_URLS') as f:
    d = json.load(f)
for url in sorted(d.keys()):
    print(url)
" | xargs -P "$PARALLEL" -I{} bash -c '
  url="$1"
  ua="'"$UA"'"
  max_time='"$MAX_TIME"'

  for attempt in 1 2 3; do
    out=$(curl -ILsS --max-time "$max_time" -A "$ua" \
        -w "|||%{http_code}|||%{url_effective}|||%{num_redirects}" \
        -o /dev/null "$url" 2>/tmp/cerr-$$)
    ec=$?
    rm -f /tmp/cerr-$$

    info="${out##*|||}"
    http_code=$(echo "$info" | cut -d"|" -f1)
    final_url=$(echo "$info" | cut -d"|" -f3)
    num_hops=$(echo "$info" | cut -d"|" -f5)

    case $ec in
      0|22) break ;;
      6)    echo "$url|||dns|||$url|||0"; exit 0 ;;
      28)   [[ $attempt -lt 3 ]] && sleep $((attempt*2)) || { echo "$url|||timeout|||$url|||0"; exit 0; } ;;
      35|51|60) echo "$url|||tls|||$url|||0"; exit 0 ;;
      *)    [[ $attempt -lt 3 ]] && sleep $((attempt*2)) || { echo "$url|||error-${ec}|||$url|||0"; exit 0; } ;;
    esac
  done

  # On 403 HEAD, try GET to distinguish bot-block
  if [[ "$http_code" == "403" ]]; then
    get_code=$(curl -LsS -o /dev/null --max-time "$max_time" -A "$ua" -w "%{http_code}" "$url" 2>/dev/null)
    [[ "$get_code" == "200" ]] && { echo "$url|||403-bot-blocked|||${final_url:-$url}|||${num_hops:-0}"; exit 0; }
  fi

  echo "$url|||${http_code:-000}|||${final_url:-$url}|||${num_hops:-0}"
' - > "$AUDIT_OUT"

echo "[4/4] Building JSON report ..."

AUDIT_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUTPUT_JSON="$OUTPUT_DIR/external-links-${PHASE}.json"
OUTPUT_MD="$OUTPUT_DIR/external-links-${PHASE}.txt"

python3 - "$CLEAN_URLS" "$AUDIT_OUT" "$OUTPUT_JSON" "$OUTPUT_MD" "$AUDIT_DATE" "$PHASE" << 'PYEOF'
import json
import sys
from collections import Counter

clean_path, audit_path, json_out, txt_out, audit_date, phase = sys.argv[1:]

with open(clean_path) as f:
    url_to_sites = json.load(f)

results = []
with open(audit_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('|||')
        if len(parts) < 4:
            continue
        url, raw_status, final_url, hops = parts[0], parts[1], parts[2], parts[3]
        hops = int(hops) if hops.isdigit() else 0

        # Classify
        if raw_status in ('dns', 'tls', 'timeout'):
            classification = raw_status
        elif raw_status == '403-bot-blocked':
            classification = '403-bot-blocked'
        elif raw_status.startswith('error-'):
            classification = raw_status
        else:
            try:
                code = int(raw_status)
            except ValueError:
                code = 0
            if code == 200:
                if hops >= 3:
                    classification = f'chain-{hops}→200'
                elif hops > 0:
                    classification = '301→200'
                else:
                    classification = '200'
            elif code == 404:
                classification = '404'
            elif code == 410:
                classification = '410'
            elif code == 403:
                classification = '403'
            elif 400 <= code < 500:
                classification = 'other-4xx'
            elif 500 <= code < 600:
                classification = '5xx'
            elif code == 0:
                classification = 'unknown'
            else:
                classification = str(code)

        results.append({
            "url": url,
            "classification": classification,
            "final_url": final_url,
            "redirect_hops": hops,
            "http_status": int(raw_status) if raw_status.isdigit() else 0,
            "use_sites": url_to_sites.get(url, []),
            "notes": ""
        })

counts = Counter(r['classification'] for r in results)
report = {
    "audit_date": audit_date,
    "auditor": "Link Auditor (escalated to Sonnet 4.6)",
    "phase": phase,
    "total_unique_urls": len(url_to_sites),
    "audited": len(results),
    "skipped_placeholders": "see extraction step",
    "skipped_command_literals": 0,
    "classification_counts": dict(counts),
    "results": sorted(results, key=lambda r: r['url'])
}

with open(json_out, 'w') as f:
    json.dump(report, f, indent=2)

# Summary text
lines = [f"External Link Audit — {phase} — {audit_date}", ""]
for cls, cnt in sorted(counts.items()):
    lines.append(f"  {cls}: {cnt}")
lines.append(f"\nTotal audited: {len(results)}")
lines.append(f"Output: {json_out}")

with open(txt_out, 'w') as f:
    f.write('\n'.join(lines) + '\n')

print('\n'.join(lines))
PYEOF

echo ""
echo "Audit complete."
echo "JSON: $OUTPUT_JSON"
echo "Summary: $OUTPUT_MD"
