#!/usr/bin/env bash
# setup-oci-cli.sh — install OCI CLI + Terraform (macOS/Homebrew).
# (Opsional; CLI juga bisa diinstal manual via https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
set -euo pipefail

echo "== Install OCI CLI =="
if command -v oci >/dev/null 2>&1; then
  echo "Sudah ada: $(oci --version)"
else
  brew update
  brew install oci-cli
  oci --version
fi

echo
echo "== Install Terraform =="
if command -v terraform >/dev/null 2>&1; then
  echo "Sudah ada: $(terraform version | head -1)"
else
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
  terraform version
fi

echo
echo "== Langkah berikutnya (manual) =="
echo "1) Buat user OCI + API key di console (Identity > Users > API Keys)."
echo "2) Jalankan:  oci setup config   (region: ap-singapore-1)"
echo "3) Isi terraform/terraform.tfvars lalu plan/apply (lihat terraform/README.md)."
