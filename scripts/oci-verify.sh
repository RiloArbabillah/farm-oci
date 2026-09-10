#!/usr/bin/env bash
# oci-verify.sh — verifikasi status akun/region/kuota OCI dari config lokal.
# Prasyarat: OCI CLI terinstal & `oci setup config` sudah jalan (api-singapore-1).
set -euo pipefail

echo "== 1. Region/home region (harus ap-singapore-1) =="
if command -v oci >/dev/null 2>&1; then
  REGION=$(oci iam region-subscription list 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(r['region-name'] for r in d.get('data',[])))" 2>/dev/null || echo "UNKNOWN")
  echo "Region subscription: ${REGION:-UNKNOWN}"
else
  echo "WARN: OCI CLI tidak terinstal — install: brew install oci-cli"
fi

echo "== 2. Account type & kuota A1 =="
echo "Cek manual di console:"
echo "  Governance & Administration -> Limits, Quotas and Usage"
echo "  - Account type harus: Pay As You Go (bukan Trial)"
echo "  - Limit VM.Standard.A1.Flex OCPU harus: 4"
echo
echo "== 3. Tenancy (dari config lokal, terenkripsi/diredacted) =="
ls -la ~/.oci/config >/dev/null 2>&1 && echo "OK: ~/.oci/config ada" || echo "BELUM ADA ~/.oci/config — jalankan: oci setup config"
ls ~/.oci/*.pem >/dev/null 2>&1 && echo "OK: API private key ada di ~/.oci/" || echo "BELUM ADA API key — buat via console IAM > API Keys"
echo
echo "== 4. Koneksi API (non-mutating) =="
if command -v oci >/dev/null 2>&1 && [ -f ~/.oci/config ]; then
  oci iam compartment list --compartment-id-in-subtree true --all 2>&1 | head -5 || true
fi
