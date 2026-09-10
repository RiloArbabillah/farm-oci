variable "tenancy_ocid" {
  description = "OCID tenancy (Tenancy Details)."
  type        = string
}

variable "user_ocid" {
  description = "OCID dari user OCI (disarankan user khusus, bukan root)."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint API key user (terlihat di IAM -> API Keys)."
  type        = string
}

variable "private_key_path" {
  description = "Path ke private API key (.pem). JANGAN di-commit."
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "Home region OCI."
  type        = string
  default     = "ap-singapore-1"
}

variable "compartment_ocid" {
  description = "Compartment target. Default: root tenancy (biarkan kosong untuk memakai root)."
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Path public key untuk SSH ke instance."
  type        = string
  default     = "~/.ssh/oci_farm.pub"
}

variable "ssh_public_key" {
  description = "Alternatif: isi langsung isi public key (override ssh_public_key_path)."
  type        = string
  default     = ""
}

variable "instance_name" {
  description = "Nama instance."
  type        = string
  default     = "a1-farm-sg"
}

variable "ocpus" {
  description = "Jumlah OCPU A1 Flex."
  type        = number
  default     = 2
}

variable "memory_in_gbs" {
  description = "RAM A1 Flex (GB)."
  type        = number
  default     = 12
}

variable "boot_volume_size_in_gbs" {
  description = "Ukuran boot volume (Always Free max 200 GB total)."
  type        = number
  default     = 100
}

variable "image_ocid" {
  description = "OCID image. Default dikisi otomatis oleh main.tf (Oracle Linux 8 aarch64) via data source; set manual jika mau Ubuntu 24.04."
  type        = string
  default     = ""
}

variable "my_public_ip_cidr" {
  description = "CIDR IP publik kamu untuk membatasi akses SSH (mis. 203.0.113.5/32). Wajib diisi."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain, mis. 'DLD-1' (ap-singapore-1). Jika kosong, data source mengambil AD pertama."
  type        = string
  default     = ""
}

variable "budget_amount" {
  description = "Budget bulanan USD sebagai pengaman biaya."
  type        = number
  default     = 1
}

variable "alarm_email" {
  description = "Email penerima alarm budget. Wajib diisi."
  type        = string
}
