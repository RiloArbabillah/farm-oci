# Terraform — farm-oci (ap-singapore-1)

Provision **VCN + subnet + Ampere A1 (2 OCPU / 12 GB, boot 100 GB)** + **budget alarm** di OCI.

## Prasyarat

1. Akun OCI Free Tier **sudah upgrade PAYG** dan limit `VM.Standard.A1.Flex OCPU` = 4 (lihat `../docs/RUNBOOK.md` Fase A2).
2. OCI CLI & Terraform terinstal (`../scripts/setup-oci-cli.sh`).
3. `oci setup config` selesai (private key `.pem` + `~/.oci/config`).
4. Public SSH key ada di `~/.ssh/oci_farm.pub`.

## Cara pakai

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# isi: tenancy_ocid, user_ocid, fingerprint, private_key_path,
#      my_public_ip_cidr (IP publik kamu saat ini), alarm_email

terraform init        # download provider Oracle
terraform plan        # review perubahan
terraform apply       # apply (konfirmasi 'yes')
terraform output      # lihat public IP & perintah SSH
```

## Catatan

- `terraform.tfvars` berisi info sensitif dan sudah di-`.gitignore`.
- `my_public_ip_cidr` Wajib diisi — Security List hanya membuka SSH dari IP itu.
- Jika kena `Out of host capacity` saat apply:
  ```bash
  terraform apply -var availability_domain="DLD-2"     # ganti AD
  # atau tunggu 15-60 menit lalu retry
  ```
- Untuk ubah image ke Ubuntu 24.04: isi `image_ocid` dengan OCID image aarch64 Ubuntu dari console (region `ap-singapore-1`).
- Hapus semua resource (SAVE): `terraform destroy`.

## Output

- `instance_public_ip` — IP publik A1.
- `instance_ssh_command` — perintah SSH contoh.
- `home_region`, `availability_domain` — konfirmasi region/AD terpakai.
