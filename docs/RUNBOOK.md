# RUNBOOK — Oracle Cloud Free Tier: Ampere A1 di Singapore

Runbook lengkap untuk mendapatkan VPS OCI Free Tier. Kerjakan fase **A1 → A2 di console**, lalu fase **A3 → A5** dengan CLI/Terraform dari repo ini.

---

## Fase A1 — Signup akun (manual, browser)

1. Buka **https://signup.cloud.oracle.com** (atau `oracle.com/cloud/free` → *Start for free*).
2. Pilih opsi **Tambah rincian pembayaran dan verifikasi** (kartu kredit/debit diperlukan Oracle untuk verifikasi; ada *authorization hold* 3–5 hari, **tidak ada charge**).
3. Isi:
   - Email aktif (Gmail disarankan) → verifikasi kode OTP.
   - Nomor HP → verifikasi OTP.
   - Nama lengkap sesuai kartu, alamat tagihan, negara.
   - **Country/Region**: *Singapore (Singapore) — ap-singapore-1*.
4. Pilih **home region = Singapore**. ⚠️ *Home region tidak bisa diubah setelah daftar — pastikan Singapore benar-benar muncul saat signup.*
5. Masukkan kartu → kirim → tunggu email aktivasi Oracle Cloud.
6. Login ke **https://cloud.oracle.com** dan pastikan status akun: **Trial** atau **Always Free** aktif.

**Jika signup ditolak/tidak lolos verifikasi**
- Tidak memakai kartu virtual/prepaid; pakai kartu kredit/debit reguler non-PIN.
- Pastikan alamat tagihan & nama persis sama dengan rekening bank.
- Tunggu 24 jam lalu coba lagi; atau coba browser lain / mode incognito.

---

## Fase A2 — Upgrade ke Pay As You Go (PAYG) ✅ dilakukan pertama di console

> Kenapa PAYG: akun PAYG punya relung kapasitas `VM.Standard.A1.Flex` yang lebih lapang dibanding akun Always-Free murni, jadi jauh lebih mudah menembus error **`Out of host capacity`** di region ramai (Singapore). Kuota Always Free tetap berlaku; **tidak ada tagihan selama hanya memakai kuota Always Free**.

1. Console OCI → ikon **User profile** (kanan atas) → **Tenancy: <nama tenancy>**.
2. Klik **Upgrade to Pay As You Go** → baca peringatan → konfirmasi (kartu yang sama).
3. Verifikasi: menu **Governance & Administration → Limits, Quotas and Usage** →
   - Account type = **Pay As You Go** (bukan *Trial*).
   - Limit `VM.Standard.A1.Flex OCPU` = **4** (2x lipat dari akun Always-Free murni).

**Keamanan biaya (wajib setelah upgrade, sebelum bikin VPS)**
- **Billing & Cost Management → Budgets** → buat budget **US$1/bulan** untuk *Tenancy* → aktifkan alarm **email**.
- Rule: jangan pernah memakai resource di luar kuota Always Free. Budget alarm $1 = pengaman dini, bukan izin belanja.

---

## Fase A3 — Siapkan kredensial OCI di mesin lokal

### 3.1 Install OCI CLI (macOS)

```bash
brew update && brew install oci-cli
oci --version
```

### 3.2 Install Terraform (macOS)

```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
terraform version
```

### 3.3 Buat SSH keypair khusus farm-oci

```bash
ssh-keygen -t ed25519 -f ~/.ssh/oci_farm -C "oci-farm-sg"
chmod 600 ~/.ssh/oci_farm
```

### 3.4 Buat user OCI khusus (bukan root) + API key

Di console:
1. **Identity & Security → Users** → **Create user** → nama `terraform-user` → email kamu.
2. Buka user → **API Keys** → **Add API Key** → **Generate API Key Pair** → download private `.pem` + public `.pem`.
3. `oci setup config` (di lokal) dan isi:
   - Location private key: path file `.pem` dari langkah 2.
   - User OCID → salin dari halaman user.
   - Tenancy OCID → **Tenancy Details**.
   - Region: `ap-singapore-1`.

Verifikasi config:
```bash
oci iam region list | grep ap-singapore-1   # home region terlihat
oci iam compartment list --compartment-id-in-subtree true | head
```
> Private key `.pem` JANGAN di-commit ke repo; simpan di `~/.oci/` saja.

Opsional (rekomendasi untuk keamanan): buat kredensial **API key saja tanpa password**, dan kunci user dengan policy terbatas. Untuk kemudahan awal, user bisa diberi policy `Allow group Terraformers to manage all-resources in tenancy` (perbaiki scope ke compartment setelah produksi).

---

## Fase A4 — Terraform: provision VCN + A1 instance

Lihat [`terraform/README.md`](../terraform/README.md) untuk langkah install/plan/apply.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # isi tenancy_ocid, user_ocid, dll.
terraform init
terraform plan
terraform apply -auto-approve
```

Parameter instance yang dipakai:
- Shape: `VM.Standard.A1.Flex`, **2 OCPU / 12 GB RAM** (total kuota A1).
- Boot volume: **100 GB** (masih dalam 200 GB Always Free).
- Image: Oracle Linux 8 (`aarch64`) — default; bisa ganti dengan Ubuntu 24.04 di `variables.tf`.
- VCN: `vcn-farm-sg` `10.0.0.0/16`, subnet publik `10.0.1.0/24`, Internet Gateway aktif.
- Security list: SSH `22/tcp` dari IP kamu, `80/tcp`, `443/tcp`; egress bebas.

---

## Fase A5 — Verifikasi & keepalive

### SSH masuk

```bash
ssh -i ~/.ssh/oci_farm opc@<PUBLIC_IP>   # Oracle Linux 8 (user: opc)
# atau ubuntu@<PUBLIC_IP> untuk Ubuntu
```

Perintah verifikasi:
```bash
whoami && hostname
uname -m          # harus aarch64 (ARM)
nproc             # harus 2
free -h           # harus ~12 GB
```

### Verify dari lokal

```bash
./scripts/oci-verify.sh                # cek status akun/region/kuota dari config lokal
terraform -chdir=terraform output      # public_ip, dll.
```

### Keepalive anti-reclaim (jalankan DI VPS)

Oracle dapat mereclaim instance Always Free yang idle (CPU/network/memori < 20% selama 7 hari). Pasang keepalive ringan di VPS:

```bash
# salin script lalu cron
scp -i ~/.ssh/oci_farm scripts/keepalive.sh opc@<PUBLIC_IP>:/tmp/
ssh -i ~/.ssh/oci_farm opc@<PUBLIC_IP> 'sudo mv /tmp/keepalive.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/keepalive.sh'
ssh -i ~/.ssh/oci_farm opc@<PUBLIC_IP} 'echo "*/5 * * * * /usr/local/bin/keepalive.sh" | sudo crontab -'
```

(Atau pasang uptime monitor seperti Uptime Kuma yang melakukan request berkala ke VPS.)

---

## Troubleshooting umum

| Gejala | Kemungkinan penyebab | Solusi |
|---|---|---|
| `Out of host capacity` saat create A1 | Kapasitas A1 penuh di AD tersebut | Coba AD lain (AD-1/2/3), atau tunggu 15–60 menit & retry |
| Error kapasitas terus | Akun masih status Trial/Always-Free murni | Pastikan sudah PAYG (Fase A2); retry setelah 10–30 menit |
| `Permission denied (publickey)` saat SSH | Key tidak terpasang / salah user | Coba `opc@` untuk OL8; pastikan pubkey yang di-paste waktu create instance |
| Kartu ditolak saat signup | Kartu virtual/prepaid/PIN | Ganti kartu kredit/debit reguler (bukan virtual, bukan prepaid, tanpa PIN) |
| Port 25 (smtp) tidak jalan | OCI blokir outbound port 25 default | Pakai relay email (Mailgun/Postmark) atau buka service limit request |
| Instance hilang/tidak aktif | Direclaim karena idle > reclamation threshold | Pasang keepalive, pantau CPU/memori |
| Tagihan tak terduga | Resource di luar kuota Always Free | Cek Budget + alarm; hapus resource di luar kuota |

## Referensi resmi

- OCI Always Free Resources: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Oracle Cloud Free Tier: https://www.oracle.com/cloud/free/
- OCI Regions: https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm
