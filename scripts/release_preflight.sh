#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

failed=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failed=1
}

pass() {
  printf 'PASS: %s\n' "$1"
}

require_file() {
  if [ -f "$1" ]; then pass "$1 exists"; else fail "$1 is missing"; fi
}

require_file Config.xcconfig
require_file Pinly.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
require_file Pinly/GoogleService-Info.plist

if [ ! -f Config.local.xcconfig ]; then
  fail "Config.local.xcconfig is missing"
else
  config_value() {
    sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" Config.local.xcconfig | tail -n 1 | tr -d '[:space:]'
  }

  [ -n "$(config_value REVENUECAT_API_KEY)" ] || fail "REVENUECAT_API_KEY is empty"
  [ -n "$(config_value GAD_APPLICATION_IDENTIFIER)" ] || fail "GAD_APPLICATION_IDENTIFIER is empty"
  ad_unit_id="$(config_value GAD_INTERSTITIAL_AD_UNIT_ID)"
  [ -n "$ad_unit_id" ] || fail "GAD_INTERSTITIAL_AD_UNIT_ID is empty"
  [ "$ad_unit_id" != "ca-app-pub-3940256099942544/4411468910" ] || fail "GAD_INTERSTITIAL_AD_UNIT_ID still uses Google's test value"
  [ -n "$(config_value PINLY_WEBSITE_HOST)" ] || fail "PINLY_WEBSITE_HOST is empty"
  [ -n "$(config_value PINLY_APP_STORE_ID)" ] || fail "PINLY_APP_STORE_ID is empty"
fi

if rg -q 'data-release-ready="false"|noindex,nofollow|class="draft-alert"' landing --glob 'index.html'; then
  fail "website still contains release blockers/draft legal pages"
else
  pass "website release flags are cleared"
fi

if rg -q 'https://pinly\.app' Pinly landing; then
  fail "unverified pinly.app URL is hard-coded"
else
  pass "no unverified pinly.app URL is hard-coded"
fi

for route in privacy terms support privacy-choices; do
  require_file "landing/$route/index.html"
  require_file "landing/en/$route/index.html"
done

plutil -lint Pinly/Info.plist Pinly/Pinly.entitlements Pinly/PrivacyInfo.xcprivacy Pinly.xcodeproj/project.pbxproj >/dev/null || fail "plist/project lint failed"
git diff --check >/dev/null || fail "git diff contains whitespace errors"

if [ "$failed" -ne 0 ]; then
  printf '\nRelease preflight failed. Complete SITE_REQUIRED_INPUTS.md and retry.\n' >&2
  exit 1
fi

printf '\nRelease preflight passed. Run the full Debug tests, Release archive, sandbox purchases, and device QA next.\n'
