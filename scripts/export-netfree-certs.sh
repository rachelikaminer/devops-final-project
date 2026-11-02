#!/usr/bin/env bash
# Builds certs/netfree-ca.pem for LOCAL Docker builds behind NetFree (run from Git Bash on Windows).
# It contains:
#   1. NetFree root certificates from the Windows certificate store
#   2. NetFree intermediate certificates, as presented right now by NetFree's filter
# Re-run it if the Docker build starts failing again with CERTIFICATE_VERIFY_FAILED.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p certs
out=certs/netfree-ca.pem

# 1. Root CAs from Windows
powershell -NoProfile -Command '
  Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match "O=NetFree" } | ForEach-Object {
    "-----BEGIN CERTIFICATE-----"
    [Convert]::ToBase64String($_.RawData, "InsertLineBreaks")
    "-----END CERTIFICATE-----"
  }' | tr -d '\r' > "$out"

# 2. Intermediate CAs from the live chain. NetFree also sends an intermediate signed by
#    "NetFree Sign ,Yossi", which has no trusted root and makes OpenSSL fail - so keep only
#    intermediates whose issuer is a NetFree Root CA or a NetFree Intermediate CA.
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
echo | openssl s_client -connect pypi.org:443 -servername pypi.org -showcerts 2>/dev/null \
  | awk -v dir="$tmp_dir" '/BEGIN CERT/{n++; inside=1} inside{print > (dir "/cert-" n ".pem")} /END CERT/{inside=0}'

for cert in "$tmp_dir"/cert-*.pem; do
  [ "$cert" = "$tmp_dir/cert-1.pem" ] && continue   # the site certificate itself
  if openssl x509 -in "$cert" -noout -issuer | grep -qE 'NetFree (Root|Intermediate) CA'; then
    cat "$cert" >> "$out"
  fi
done

echo "Wrote $(grep -c 'BEGIN CERTIFICATE' "$out") certificates to $out"
