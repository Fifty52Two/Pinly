#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

failed=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failed=1
}

if git ls-files | rg -qi '(\.p8$|\.p12$|\.mobileprovision$|(^|/)(id_rsa|id_ed25519)$|(^|/)(credentials|secrets?)(\.|/))'; then
  git ls-files | rg -i '(\.p8$|\.p12$|\.mobileprovision$|(^|/)(id_rsa|id_ed25519)$|(^|/)(credentials|secrets?)(\.|/))' >&2
  fail "tracked credential-like file found"
fi

if git grep -nEI 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|service[_-]?role[[:space:]]*[=:]|github_pat_|gh[pousr]_|Bearer[[:space:]]+eyJ|sk_live_' -- Pinly PinlyTests Config.xcconfig Config.local.example.xcconfig .github; then
  fail "hard-coded secret-like value found"
fi

if rg -n 'NSAllowsArbitraryLoads[[:space:]]*</key>[[:space:]]*<true|com\.apple\.security\.application-groups|keychain-access-groups' Pinly Pinly.xcodeproj; then
  fail "broad ATS or sensitive entitlement requires review"
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

printf 'PASS: no tracked private-key/token signatures, broad ATS exception, or sensitive access group found\n'
