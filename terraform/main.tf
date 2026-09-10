# farm-oci — Terraform untuk OCI Free Tier (Ampere A1, ap-singapore-1)
# Prasyarat: akun OCI PAYG + API key (lihat docs/RUNBOOK.md Fase A2-A3).

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
}

# Compartment: root jika tidak diisi.
locals {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid
  ad             = var.availability_domain != "" ? var.availability_domain : data.oci_identity_availability_domains.ads.availability_domains[0].name
  ssh_key        = var.ssh_public_key != "" ? var.ssh_public_key : file(var.ssh_public_key_path)
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Image default: Oracle Linux 8 (aarch64) yang Always Free-eligible.
data "oci_core_images" "ol8_arm" {
  compartment_id           = local.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  image_id = var.image_ocid != "" ? var.image_ocid : data.oci_core_images.ol8_arm.images[0].id
}

# ---- VCN / subnet ----
resource "oci_core_vcn" "farm_vcn" {
  compartment_id = local.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "vcn-farm-sg"
  dns_label      = "farmvcn"
}

resource "oci_core_internet_gateway" "farm_igw" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.farm_vcn.id
  enabled        = true
  display_name   = "igw-farm-sg"
}

resource "oci_core_route_table" "farm_rt" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.farm_vcn.id
  display_name   = "rt-farm-sg"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.farm_igw.id
  }
}

resource "oci_core_subnet" "farm_subnet" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.farm_vcn.id
  cidr_block     = "10.0.1.0/24"
  display_name   = "pub-farm-sg"
  dns_label      = "pubfarm"
  route_table_id = oci_core_route_table.farm_rt.id
}

# Security list: hanya SSH (dari IP kamu), HTTP, HTTPS. Egress bebas.
resource "oci_core_security_list" "farm_sl" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.farm_vcn.id
  display_name   = "sl-farm-sg"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = var.my_public_ip_cidr
    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      max = 80
      min = 80
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      max = 443
      min = 443
    }
  }
}

# ---- Instance A1 ----
resource "oci_core_instance" "a1" {
  availability_domain = local.ad
  compartment_id      = local.compartment_id
  display_name        = var.instance_name
  shape               = "VM.Standard.A1.Flex"
  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }
  metadata = {
    ssh_authorized_keys = local.ssh_key
  }
  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }
  create_vnic_details {
    subnet_id        = oci_core_subnet.farm_subnet.id
    assign_public_ip = true
    display_name     = "vnics-public-farm"
  }
  preserve_boot_volume = false
}

# ---- Budget + alarm (pengaman biaya wajib) ----
resource "oci_budget_budget" "farm_budget" {
  compartment_id                        = var.tenancy_ocid
  amount                                = var.budget_amount
  budget_processing_period_start_offset = 1
  reset_period                          = "MONTHLY"
  target_type                           = "ALL"
  display_name                          = "budget-farm-sg"
}

resource "oci_budget_alert_rule" "farm_budget_alarm" {
  budget_id      = oci_budget_budget.farm_budget.id
  type           = "FORECAST"
  threshold      = 50
  threshold_type = "PERCENTAGE"
  recipients     = var.alarm_email
  message        = "Peringatan budget farm-oci: sudah melewati 50% dari batas bulanan."
  display_name   = "alarm-farm-budget"
}

output "instance_public_ip" {
  description = "Public IP instance A1."
  value       = oci_core_instance.a1.public_ip
}

output "instance_ssh_command" {
  description = "Perintah SSH (Oracle Linux 8: user opc)."
  value       = "ssh -i ~/.ssh/oci_farm opc@${oci_core_instance.a1.public_ip}"
}

output "home_region" {
  description = "Home region dari tenancy."
  value       = data.oci_identity_tenancy.tenancy.home_region_key
}

output "availability_domain" {
  description = "Availability domain yang dipakai."
  value       = local.ad
}
