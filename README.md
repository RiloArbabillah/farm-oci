# farm-oci

Bootstrap dan automasi untuk mendapatkan VPS **Oracle Cloud Infrastructure (OCI) Free Tier** — target: **Ampere A1 (ARM)** di region **Singapore (ap-singapore-1)**, lalu di-provision via Terraform.

> Dokumen ini adalah **panduan eksekusi** (runbook) bertahap. Fase **A (signup + PAYG)** wajib dikerjakan manual di console Oracle; fase **B (Terraform)** baru bisa dijalankan setelah akun siap dan kredensial OCI tersedia.

## Ringkasan strategi

1. Daftar akun Oracle Cloud Free Tier baru → home region **Singapore (`ap-singapore-1`)**.
2. Segera **upgrade ke PAYG** (masih $0 selama hanya memakai kuota Always Free) supaya kuota/kapasitas `VM.Standard.A1.Flex` lebih lapang dan bisa menembus error *out of host capacity*.
3. Provision **1× A1 VM: 2 OCPU / 12 GB RAM / boot 100 GB** + VCN + security list + budget alarm $1.
4. Pasang keepalive ringan supaya instance tidak direclaim Oracle karena idle (CPU/network/memori < 20% selama 7 hari).

## Struktur repo

```
farm-oci/
├── README.md            # runbook ini
├── docs/
│   └── RUNBOOK.md       # panduan signup, PAYG, dan langkah eksekusi detail
├── scripts/
│   ├── signup-checklist.sh # checklist interaktif signup (manual, anti-lupa data)
│   ├── setup-oci-cli.sh    # install OCI CLI + setup profile (manual-by-user)
│   ├── oci-verify.sh       # verifikasi akun/region/kuota & kesehatan VPS
│   └── keepalive.sh        # (opsional) cron keepalive anti-reclaim untuk VPS
└── terraform/
    ├── main.tf          # VCN, subnet, A1 instance, budget, alarm
    ├── variables.tf
    ├── terraform.tfvars.example
    └── README.md        # cara pakai Terraform (instalasi, provider, plan, apply)
```

## Alur singkat (0 → VPS hidup)

| Fase | Aksi | Dimana | Est. waktu |
|---|---|---|---|
| A1 | Signup akun + verifikasi kartu | `scripts/signup-checklist.sh` → browser | 15–30 mnt |
| A2 | Upgrade ke Pay As You Go | console OCI | 5–10 mnt |
| A3 | Instal OCI CLI + buat API key (user baru) | mesin lokal | 10 mnt |
| A4 | `terraform plan` + `terraform apply` | repo ini | 15–30 mnt |
| A5 | Verifikasi SSH + budget alarm + keepalive | lokal + console | 10 mnt |

Detail setiap fase ada di [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

## Prasyarat DevOps (mesin lokal)

- Git, Homebrew (macOS) untuk instalasi `oci` CLI & `terraform`.
- Browser + email aktif + kartu kredit/debit non-virtual (untuk signup & PAYG).
- SSH keypair (bisa dibuat manual: `ssh-keygen -t ed25519 -f ~/.ssh/oci_farm`).

## Catatan penting

- **1 akun per orang**; kartu virtual/prepaid/TANPA-PIN **tidak diterima** Oracle.
- Home region **tidak bisa diubah** setelah daftar.
- Harga/kuota selalu cek dokumentasi resmi; isi repo ini hanya panduan, bukan jaminan ketersediaan kapasitas.
