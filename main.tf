terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "pool" {
  default = "ssd-pool"
}

variable "template_path" {
  default = "/mnt/SSD/libvirt/templates/template.img"
}

variable "vm_count" {
  default = 3
}

variable "vm_name_prefix" {
  default = "w2025-lab"
}

variable "memory_mib" {
  default = 6144
}

variable "vcpu" {
  default = 6
}

locals {
  vm_names = [
    for i in range(var.vm_count) :
    format("%s-%02d", var.vm_name_prefix, i + 1)
  ]
}

resource "libvirt_volume" "vm_disk" {
  for_each = toset(local.vm_names)

  name = "${each.key}.img"
  pool = var.pool

  target = {
    format = {
      type = "raw"
    }
  }

  create = {
    content = {
      url = "file://${var.template_path}"
    }
  }
}

resource "libvirt_domain" "vm" {
  for_each = toset(local.vm_names)

  name = each.key
  type = "kvm"

  memory      = var.memory_mib
  memory_unit = "MiB"
  vcpu        = var.vcpu

  running   = true
  autostart = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"

    loader          = "/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
    loader_readonly = "yes"
    loader_type     = "pflash"

    nv_ram = {
      nv_ram   = "/var/lib/libvirt/qemu/nvram/${each.key}.fd"
      template = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
      format   = "raw"
    }

    boot_devices = [
      { dev = "hd" }
    ]
  }

  features = {
    acpi = true
    apic = {}
  }

  cpu = {
    mode = "host-passthrough"
  }

  clock = {
    offset = "localtime"
  }

  devices = {
    disks = [
      {
        device = "disk"

        source = {
          file = {
            file = libvirt_volume.vm_disk[each.key].path
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }

        driver = {
          type = "raw"
        }
      }
    ]

    interfaces = [
      {
        model = {
          type = "virtio"
        }

        source = {
          bridge = {
            bridge = "bridge0"
          }
        }
      }
    ]

    inputs = [
      {
        type = "tablet"
        bus  = "usb"
      }
    ]

    graphics = [
      {
        spice = {
          autoport = "yes"
        }
      }
    ]

    video = [
      {
        model = {
          type = "qxl"
        }
      }
    ]
  }
}