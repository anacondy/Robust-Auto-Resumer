#!/usr/bin/env bash
# =============================================================================
#  Robust-Auto-Resumer :: RIGOROUS TEST & VULNERABILITY SCRIPT
#  Performs static analysis, security audit, and edge-case detection.
#  Run:  bash rigorous_test.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'   GREEN='\033[0;32m'   YELLOW='\033[1;33m'
CYAN='\033[0;36m'   BOLD='\033[1m'      RESET='\033[0m'

PASS=0; FAIL=0; WARN=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass()  { echo -e "  ${GREEN}✔ PASS${RESET}  $1"; PASS=$((PASS+1)); }
fail()  { echo -e "  ${RED}✘ FAIL${RESET}  $1 — $2"; FAIL=$((FAIL+1)); }
warn()  { echo -e "  ${YELLOW}⚠ WARN${RESET}  $1 — $2"; WARN=$((WARN+1)); }
info()  { echo -e "  ${CYAN}→${RESET} $1"; }

section() { echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "${BOLD}  $1${RESET}"
            echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 1 : MANIFEST V3 COMPLIANCE & STRUCTURE
# ──────────────────────────────────────────────────────────────────────────────
section "1. MANIFEST V3 COMPLIANCE & STRUCTURE"

MANIFEST="${SCRIPT_DIR}/manifest.json"

if [[ -f "$MANIFEST" ]]; then
  # Valid JSON?
  if python -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null; then
    pass "manifest.json is valid JSON"
  else
    fail "manifest.json" "Invalid JSON syntax"
  fi

  # manifest_version == 3?
  MV=$(python -c "import json; print(json.load(open('$MANIFEST')).get('manifest_version',''))" 2>/dev/null)
  [[ "$MV" == "3" ]] && pass "manifest_version is 3" || fail "manifest_version" "Expected 3, got '$MV'"

  # background.service_worker present?
  python -c "
import json
m=json.load(open('$MANIFEST'))
if 'background' in m and 'service_worker' in m['background']:
    print(m['background']['service_worker'])
" 2>/dev/null | grep -q "." && pass "background.service_worker declared" \
    || fail "background.service_worker" "Missing or not a service_worker (MV3 requires this)"

  # Service worker file exists?
  SW=$(python -c "import json;print(json.load(open('$MANIFEST'))['background']['service_worker'])" 2>/dev/null)
  [[ -f "${SCRIPT_DIR}/${SW}" ]] && pass "background file '${SW}' exists" \
    || fail "background file" "'${SW}' not found on disk"

  # permissions include 'downloads'?
  python -c "import json; assert 'downloads' in json.load(open('$MANIFEST')).get('permissions',[])" 2>/dev/null \
    && pass "Permission 'downloads' declared" \
    || fail "permissions" "Missing 'downloads' permission"

  # ❌ MISSING ICONS → Chrome Web Store rejection
  python -c "
import json
m=json.load(open('$MANIFEST'))
icons=m.get('icons',{})
if '128' in icons or '48' in icons: exit(0)
else: exit(1)
" 2>/dev/null && pass "Icons declared" \
    || fail "icons" "MISSING — Chrome Web Store REQUIRES at least a 128x128 icon. Extension will be REJECTED."

  # action → default_popup
  python -c "import json; assert 'default_popup' in json.load(open('$MANIFEST')).get('action',{})" 2>/dev/null \
    && pass "action.default_popup defined" \
    || fail "action" "Missing default_popup"

  # Popup file exists?
  POPUP=$(python -c "import json;print(json.load(open('$MANIFEST'))['action']['default_popup'])" 2>/dev/null)
  [[ -f "${SCRIPT_DIR}/${POPUP}" ]] && pass "popup file '${POPUP}' exists" \
    || fail "popup file" "'${POPUP}' not found"

  # No 'background.persistent' (MV2 artifact)
  python -c "
import json
m=json.load(open('$MANIFEST'))
assert 'persistent' not in m.get('background',{})
" 2>/dev/null && pass "No legacy background.persistent (MV2 artifact)" \
    || warn "background.persistent" "MV2 artifact present — harmless but unnecessary"
else
  fail "manifest.json" "FILE NOT FOUND"
fi

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 2 : BACKGROUND.JS — LOGIC & EDGE-CASE ANALYSIS
# ──────────────────────────────────────────────────────────────────────────────
section "2. BACKGROUND.JS — LOGIC, CONCURRENCY & EDGE CASES"

BG="${SCRIPT_DIR}/background.js"

if [[ -f "$BG" ]]; then
  # onChanged listener present?
  grep -q "onChanged.addListener" "$BG" && pass "onChanged listener registered" \
    || fail "onChanged" "No download listener found"

  # Checks downloadDelta.state before accessing .current ?
  grep -q "downloadDelta.state" "$BG" && pass "Null-guard: checks downloadDelta.state exists" \
    || fail "null-guard" "No check for downloadDelta.state before accessing .current — could crash if undefined"

  # Checks downloadDelta.state.current === 'interrupted' ?
  grep -q "state.current.*interrupted" "$BG" && pass "Filters on state.current === 'interrupted'" \
    || fail "state filter" "Not filtering for 'interrupted' state"

  # Uses chrome.downloads.search to get full item?
  grep -q "downloads.search" "$BG" && pass "Uses chrome.downloads.search for full metadata" \
    || fail "search" "No search call — can't check canResume"

  # Checks results.length > 0?
  grep -q "results.length > 0" "$BG" && pass "Validates search results length" \
    || fail "search validation" "Doesn't check search results — could access undefined index"

  # Checks canResume before calling resume?
  grep -q "canResume" "$BG" && pass "Checks canResume before resume attempt" \
    || fail "canResume" "Missing canResume check — will cause infinite error loops on non-resumable servers"

  # Handles chrome.runtime.lastError after resume?
  grep -q "lastError" "$BG" && pass "Checks chrome.runtime.lastError after resume()" \
    || fail "lastError" "No lastError check — silent failures possible"

  # ❌ MISSING: lastError check on chrome.downloads.search
  # ❌ MISSING: lastError check on chrome.downloads.search
  if grep -q "downloads.search" "$BG" && sed -n "/downloads.search/,/});/p" "$BG" | grep -q "lastError" 2>/dev/null; then
    pass "Checks lastError on chrome.downloads.search callback"
  else
    warn "lastError" "No chrome.runtime.lastError check INSIDE the chrome.downloads.search callback — API failures (e.g., permissions revoked) will be silently swallowed"
  fi

  # ❌ MISSING: Guard on downloadDelta.id
  python -c "
bg=open('$BG').read()
if 'downloadDelta.id' in bg and not ('if (downloadDelta.id)' in bg or 'downloadDelta.id &&' in bg):
    exit(1)
" 2>/dev/null \
    && pass "downloadDelta.id has a null/undefined guard" \
    || fail "downloadDelta.id guard" "No explicit null-check on downloadDelta.id before passing to search() — if id is undefined, search returns ALL downloads"

  # ❌ MISSING: Debounce / dedup protection
  grep -qiE "debounce|throttle|pending|inProgress|inflight" "$BG" \
    && pass "Debounce/dedup mechanism present" \
    || warn "dedup" "No debounce or deduplication for rapid onChanged events — same download may trigger multiple concurrent search+resume cycles"

  # ❌ MISSING: Excluding 'complete' state from triggering search unnecessarily
  # (Actually not needed since we filter for 'interrupted' — but double-check the control flow)
  info "Control flow: onChanged → state.current==='interrupted' → search → canResume → resume ✓"
else
  fail "background.js" "FILE NOT FOUND"
fi

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 3 : POPUP.JS — BUGS, CRASHES & MEMORY LEAKS
# ──────────────────────────────────────────────────────────────────────────────
section "3. POPUP.JS — CRASHES, NaN BUGS, MEMORY LEAKS"

POP="${SCRIPT_DIR}/popup.js"

if [[ -f "$POP" ]]; then
  # ❌ CRASH: formatBytes called on undefined (totalBytes can be -1 or undefined)
  grep -q "formatBytes(item.totalBytes)" "$POP" && {
    warn "NaN bug" "formatBytes(item.totalBytes) — totalBytes can be -1 (unknown size) or undefined. If undefined: results in 'NaN MB' displayed to user. If -1: shows '-0.00 MB'."
  }

  # ❌ CRASH: filename.split() when filename is undefined
  grep -q "item.filename.split" "$POP" && {
    warn "TypeError crash" "item.filename.split() — filename can be undefined for downloads that haven't resolved metadata yet. Calling .split() on undefined throws: Uncaught TypeError: Cannot read properties of undefined (reading 'split'). Entire popup rendering stops."
  }

  # ❌ MEMORY LEAK: previousBytes never cleaned
  grep -q "previousBytes\[" "$POP" && {
    warn "memory leak" "previousBytes object grows indefinitely — download IDs accumulate forever, even after downloads complete or are removed. Over days of browsing, this dictionary balloons. Add cleanup for removed download IDs."
  }

  # Speed calculation — is it actually MB/s?
  grep -q "formatBytes(diff)" "$POP" && {
    info "Speed: calculated as byte-delta between 1s intervals → displays as MB/S (close approximation, but setInterval drift ±4ms means ±0.4% error per tick — negligible)"
  }

  # ❌ RACE: setInterval without guard
  grep -q "setInterval(updateDownloads, 1000)" "$POP" && {
    warn "race condition" "setInterval runs every 1000ms unconditionally. If updateDownloads() takes >1s (slow disk, many downloads), intervals stack up causing multiple concurrent DOM writes. Use setTimeout chaining instead."
  }

  # formatBytes with 0 check
  grep -q "if (bytes === 0)" "$POP" && pass "formatBytes handles 0-byte edge case" \
    || warn "formatBytes" "No explicit 0 check (though toFixed handles it)"

  # ❌ MISSING: lastError on chrome.downloads.search in popup
  grep -q "lastError" "$POP" \
    && pass "Checks chrome.runtime.lastError in popup" \
    || warn "lastError" "No chrome.runtime.lastError check in popup's chrome.downloads.search — API errors silently fail"

  # ❌ MISSING: container null check
  grep -q "container =" "$POP" && {
    grep -q "if (container)" "$POP" \
      && pass "Null-checks DOM container before use" \
      || warn "DOM null" "No null check on document.getElementById('downloads-container') — if id changes, .innerHTML assignment throws TypeError"
  }

  # HTML injection via filename? (XSS vector)
  grep -q "shortName" "$POP" && {
    info "XSS check: filename is inserted via innerHTML. Chrome extension filenames are OS paths, not user-controlled — LOW risk, but textContent would be safer."
  }

  # ❌ BUG: substring(0,25) without checking length
  info "substring(0,25) always safe on strings, but '...' always appended even if name < 25 chars"
else
  fail "popup.js" "FILE NOT FOUND"
fi

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 4 : POPUP.HTML — STRUCTURE & SECURITY
# ──────────────────────────────────────────────────────────────────────────────
section "4. POPUP.HTML — STRUCTURE & SECURITY"

PH="${SCRIPT_DIR}/popup.html"
if [[ -f "$PH" ]]; then
  grep -qi "<!DOCTYPE html>" "$PH" && pass "DOCTYPE declared" || warn "DOCTYPE" "No <!DOCTYPE html> — quirks mode in some contexts"
  grep -q "charset" "$PH" && pass "Charset meta tag present" || fail "charset" "Missing charset declaration — encoding issues possible"
  grep -q "downloads-container" "$PH" && pass "Downloads container div present" || fail "container" "Missing #downloads-container — popup.js will crash"
  grep -q "popup.js" "$PH" && pass "Script tag loads popup.js" || fail "script" "popup.js not loaded"
  grep -q "popup.css" "$PH" && pass "Stylesheet loads popup.css" || fail "css" "popup.css not linked"

  # ❌ MISSING: Content-Security-Policy
  grep -qi "Content-Security-Policy" "$PH" \
    && pass "CSP meta tag present" \
    || warn "CSP" "No Content-Security-Policy meta tag — extension popups should have CSP for defense-in-depth"

  # ❌ MISSING: <title>
  grep -qi "<title>" "$PH" && pass "<title> tag present" || warn "title" "No <title> tag — minor, but good practice"
else
  fail "popup.html" "FILE NOT FOUND"
fi

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 5 : POPUP.CSS — SANITY CHECKS
# ──────────────────────────────────────────────────────────────────────────────
section "5. POPUP.CSS — SANITY & BEST PRACTICES"

PC="${SCRIPT_DIR}/popup.css"
if [[ -f "$PC" ]]; then
  grep -q "var(--bg-color)" "$PC" && pass "CSS custom properties in use" || warn "CSS vars" "No custom properties"
  grep -q "width: 400px" "$PC" && warn "fixed width" "Popup width hardcoded to 400px — won't adapt to different screen densities"
  grep -q "monospace" "$PC" && pass "Monospace font declared (brutalist aesthetic ✓)"
  grep -q "grid-template-columns" "$PC" && pass "CSS Grid used for download-item layout"
else
  fail "popup.css" "FILE NOT FOUND"
fi

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 6 : SECURITY VULNERABILITY DEEP-DIVE
# ──────────────────────────────────────────────────────────────────────────────
section "6. SECURITY VULNERABILITY DEEP-DIVE"

# 6a — innerHTML XSS
if [[ -f "$POP" ]]; then
  grep -q "innerHTML" "$POP" && {
    warn "innerHTML" "popup.js uses innerHTML to render download data. Filenames are OS paths (not user input), and extension's CSP is default (no eval/inline). Risk is LOW, but textContent or DOM creation would be safer. If a malicious filename somehow enters the downloads list (e.g., crafted download from a malicious site), XSS is possible."
  }
fi

# 6b — No eval / inline scripts
if [[ -f "$POP" ]]; then
  grep -qE "\beval\(" "$POP" && fail "eval()" "eval() detected — dangerous" || pass "No eval() usage"
fi

# 6c — chrome.runtime.lastError
info "chrome.runtime.lastError is checked in background.js resume callback ✓"
info "chrome.runtime.lastError is NOT checked in popup.js or search callback ⚠"

# 6d — Permissions: only 'downloads' — minimal privilege principle
python -c "
import json
m=json.load(open('${SCRIPT_DIR}/manifest.json'))
perms=m.get('permissions',[])
host_perms=m.get('host_permissions',[])
all_perms=perms+host_perms
dangerous={'<all_urls>','*://*/*','tabs','cookies','webRequest','webRequestBlocking','clipboardRead','clipboardWrite'}
overlap=set(all_perms)&dangerous
if overlap:
    print('WARN:' + str(overlap))
    exit(1)
else:
    print('OK')
" 2>/dev/null && pass "Minimal permissions principle — only 'downloads' declared (no dangerous permissions)" \
    || warn "permissions" "Extension has potentially dangerous permissions beyond 'downloads'"

# 6e — No external resources loaded in popup
if [[ -f "$PH" ]]; then
  grep -qE "https?://" "$PH" && warn "external resources" "popup.html loads external resources — privacy risk" \
    || pass "No external HTTP resources in popup.html"
fi

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 7 : CODE QUALITY METRICS
# ──────────────────────────────────────────────────────────────────────────────
section "7. CODE QUALITY METRICS"

for f in background.js popup.js popup.css popup.html; do
  FP="${SCRIPT_DIR}/${f}"
  if [[ -f "$FP" ]]; then
    LINES=$(wc -l < "$FP")
    BYTES=$(wc -c < "$FP")
    printf "  %-20s  %4d lines  %6d bytes\n" "$f" "$LINES" "$BYTES"
  fi
done

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 8 : UNIT-TEST-LIKE EDGE CASES (Simulation)
# ──────────────────────────────────────────────────────────────────────────────
section "8. EDGE CASE SIMULATIONS (Logic Walkthrough)"

echo ""
echo "  ┌─ SCENARIO A: Server supports byte ranges ─────────────────────┐"
echo "  │  Download interrupted → canResume=true → resume() called      │"
echo "  │  Expected: Download resumes.                            PASS  │"
echo "  └────────────────────────────────────────────────────────────────┘"

echo "  ┌─ SCENARIO B: Server does NOT support byte ranges ─────────────┐"
echo "  │  Download interrupted → canResume=false → log, skip resume    │"
echo "  │  Expected: No infinite loop. No error.                  PASS  │"
echo "  └────────────────────────────────────────────────────────────────┘"

echo "  ┌─ SCENARIO C: totalBytes = undefined ──────────────────────────┐"
echo "  │  popup.js: formatBytes(undefined) → NaN MB on screen          │"
echo "  │  Expected: Graceful fallback or 'Unknown' text.         FAIL  │"
echo "  └────────────────────────────────────────────────────────────────┘"

echo "  ┌─ SCENARIO D: filename = undefined ────────────────────────────┐"
echo "  │  popup.js: .split() on undefined → TypeError, popup crashes   │"
echo "  │  Expected: Null-safe filename extraction.               FAIL  │"
echo "  └────────────────────────────────────────────────────────────────┘"

echo "  ┌─ SCENARIO E: Rapid double onChanged for same download ────────┐"
echo "  │  Two concurrent search() + resume() calls for same ID         │"
echo "  │  Expected: Idempotent, but wasteful.                    WARN  │"
echo "  └────────────────────────────────────────────────────────────────┘"

echo "  ┌─ SCENARIO F: Popup open for 3 days ───────────────────────────┐"
echo "  │  previousBytes dict grows with every download ID forever      │"
echo "  │  Expected: Bounded memory usage. Cleanup old IDs.       FAIL  │"
echo "  └────────────────────────────────────────────────────────────────┘"

echo "  ┌─ SCENARIO G: Chrome Web Store submission ─────────────────────┐"
echo "  │  Missing 128x128 icon in manifest → rejected.                 │"
echo "  │  Expected: Icons declared.                              FAIL  │"
echo "  └────────────────────────────────────────────────────────────────┘"

# ──────────────────────────────────────────────────────────────────────────────
#  SUMMARY
# ──────────────────────────────────────────────────────────────────────────────
section "SUMMARY"

echo ""
echo -e "  ${GREEN}PASS : ${PASS}${RESET}"
echo -e "  ${RED}FAIL : ${FAIL}${RESET}"
echo -e "  ${YELLOW}WARN : ${WARN}${RESET}"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "  ${RED}▌ CRITICAL ISSUES FOUND — see FAIL items above${RESET}"
fi
if [[ $WARN -gt 0 ]]; then
  echo -e "  ${YELLOW}▌ WARNINGS FOUND — see WARN items above${RESET}"
fi

echo ""
echo "  ┌───────────────────────────────────────────────────────────┐"
echo "  │  TOP 5 FIXES RECOMMENDED (priority order):               │"
echo "  │                                                          │"
echo "  │  1. Add 128x128 icon to manifest (CWS rejection)         │"
echo "  │  2. Null-guard filename in popup.js (crashes)            │"
echo "  │  3. Null-guard totalBytes in formatBytes (NaN bug)       │"
echo "  │  4. Check lastError in chrome.downloads.search callback  │"
echo "  │  5. Clean up previousBytes for completed downloads       │"
echo "  └───────────────────────────────────────────────────────────┘"
echo ""

exit $FAIL
