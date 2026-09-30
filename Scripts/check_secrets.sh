#!/usr/bin/env bash
# Look for GitHub tokens and private keys in the files a commit would include, and fail if
# any is found. The patterns are strict on purpose: a loose "ghp_" would also match the
# placeholder SecureField("ghp_… (optional)") in the import sheet.
#
# Use it manually before committing:   ./Scripts/check_secrets.sh
# Or make it automatic:                ln -sf ../../Scripts/check_secrets.sh .git/hooks/pre-commit
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATTERN='ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|gho_[A-Za-z0-9]{36}|ghs_[A-Za-z0-9]{36}|ghu_[A-Za-z0-9]{36}|-----BEGIN [A-Z ]*PRIVATE KEY-----'

found=0
while IFS= read -r file; do
  [ -f "$file" ] || continue
  if grep -IqE "$PATTERN" "$file" 2>/dev/null; then
    echo "✗ possible secret in $file"
    found=1
  fi
done < <(git ls-files --cached --others --exclude-standard)

if [ "$found" -eq 1 ]; then
  echo
  echo "Nothing was changed. Remove the secret, revoke it on GitHub, then commit again."
  exit 1
fi

echo "✓ no GitHub tokens or private keys in the files that would be committed"