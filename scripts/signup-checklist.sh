#!/usr/bin/env bash
# signup-checklist.sh - Checklist interaktif signup Oracle Cloud Free Tier.
#
# Tujuan:
#  - Menyiapkan data yang kamu butuhkan agar tinggal menyalin ke form signup.
#  - Memandu langkah signup manual (OTP, kartu, PAYG) hingga siap Terraform.
#
# Batas otomasi (sesuai panduan):
#  - OTP email/SMS, verifikasi kartu, dan reCAPTCHA WAJIB manual oleh kamu.
#  - Script ini TIDAK mengotomasi pendaftaran akun / tidak memakai data fiktif.
#
# Hasil: setelah selesai semua langkah, isi terraform/terraform.tfvars lalu jalankan
# terraform plan/apply sesuai terraform/README.md. SSH ke instance pakai
# `~/.ssh/oci_farm` (key dibuat otomatis jika belum ada).
set -u

CFG="${FARM_OCI_CFG:-$HOME/.farm-oci-signup.env}"
mkdir -p "$(dirname "$CFG")" 2>/dev/null; chmod 700 "$(dirname "$CFG")" 2>/dev/null || true

info() { printf '\033[0;36m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
fail() { printf '\033[0;31m[x]\033[0m %s\n' "$*"; }

GEN_SSH_DONE=0
gen_ssh() {
  [ "$GEN_SSH_DONE" = 1 ] && return 0
  GEN_SSH_DONE=1
  local key="$HOME/.ssh/oci_farm"
  if [ -f "$key" ]; then
    ok "SSH key sudah ada: $key"
  else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$key" -C "oci-farm-sg" -N "" >/dev/null 2>&1
    chmod 600 "$key"
    ok "SSH key dibuat: $key (public: $key.pub)"
  fi
}

prompt() {
  local var="$1" label="$2" val
  if [ -f "$CFG" ]; then
    val=$(grep -E "^${var}=" "$CFG" 2>/dev/null | head -1 | cut -d= -f2-)
  fi
  if [ -z "${val:-}" ]; then
    printf '%s: ' "$label"
    IFS= read -r val || val=""
    [ -n "$val" ] && printf '%s=%s\n' "$var" "$val" >> "$CFG"
  else
    printf '\033[0;32m%s\033[0m (tersimpan): %s\n' "$var" "$val"
  fi
}

ask_yes() {
  local q="$1"; local ans
  printf '%s (y/N) ' "$q"
  IFS= read -r ans || ans="n"
  case "$ans" in [yY]|[yY][eE][sS]) return 0;; *) return 1;; esac
}

begin() { printf '\n=== %s ===\n' "$*"; }

main() {
  printf '\n'
  info 'Oracle Cloud Free Tier - checklist interaktif (signup manual, data kamu)'
  printf '\n'

  begin 'Data yang akan dipakai di form signup'
  info 'Ketik data kamu di bawah (disimpan lokal ke %s, tidak dikirim ke mana pun).' "$CFG"
  prompt EMAIL      '  Email aktif (Gmail disarankan)'
  prompt FULLNAME   '  Nama lengkap sesuai kartu'
  prompt COUNTRY    '  Negara (mis. Indonesia)'
  prompt PHONE      '  Nomor HP (mis. +62...)'
  prompt ADDR       '  Alamat tagihan (jalan, kota, kode pos)'
  prompt CARD_TYPE  '  Jenis kartu (credit | debit) - non-virtual, tanpa PIN'
  prompt HOME_REGION '  Home region (disarankan ap-singapore-1)'
  gen_ssh

  begin 'Langkah 1/5 - Signup'
  info 'Buka https://signup.cloud.oracle.com di browser Anda, lalu isi form sesuai data di atas.'
  if ask_yes '  Sudah submit signup & menerima email aktivasi Oracle Cloud?'; then
    ok 'Akun terdaftar.'
  else
    fail 'Selesaikan signup dulu (cek email termasuk folder spam), lalu jalankan ulang script ini.'
    exit 1
  fi

  begin 'Langkah 2/5 - Upgrade ke Pay As You Go'
  info 'Login https://cloud.oracle.com -> ikon user (kanan atas) -> Tenancy -> Upgrade to Pay As You Go'
  if ask_yes '  Sudah upgrade ke PAYG?'; then
    ok 'PAYG aktif.'
  else
    fail 'Upgrade PAYG wajib dulu. Ulangi script setelah selesai.'
    exit 1
  fi

  begin 'Langkah 3/5 - Verifikasi kuota A1'
  info 'Cek: Governance & Administration -> Limits, Quotas and Usage'
  if ask_yes '  Limit VM.Standard.A1.Flex OCPU = 4?'; then
    ok 'Kuota A1 = 4 OCPU.'
  else
    fail 'Kuota belum 4 OCPU. Pastikan proses PAYG selesai, lalu ulangi script.'
    exit 1
  fi

  begin 'Langkah 4/5 - Budget & alarm biaya (wajib)'
  info 'Buat: Billing & Cost Management -> Budgets (US$1/bulan) + alarm email.'
  if ask_yes '  Budget US$1/bulan + alarm email sudah dibuat?'; then
    ok 'Budget alarm aktif.'
  else
    fail 'JANGAN lanjut sebelum budget dibuat.'
    exit 1
  fi

  begin 'Langkah 5/5 - Siapkan CLI & API key'
  info 'Langkah berikutnya (lihat docs/RUNBOOK.md Fase A3):'
  info '  - Jalankan scripts/setup-oci-cli.sh untuk instal OCI CLI & Terraform.'
  info '  - Buat user OCI khusus + API key di console, lalu `oci setup config`.'

  printf '\n'
  ok 'Checklist selesai. Ringkasan:'
  printf '  - Data signup tersimpan di: %s (hapus file ini untuk reset)\n' "$CFG"
  printf '  - SSH key: %s\n' "$HOME/.ssh/oci_farm.pub"
  printf '  - Berikutnya: terraform/terraform.tfvars -> terraform plan/apply\n'
}

main "$@"
