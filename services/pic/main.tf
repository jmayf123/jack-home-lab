terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

# pic - Immich self-hosted photo/video backup
resource "proxmox_lxc" "pic" {
  target_node  = "pve"
  hostname     = "pic"
  vmid         = 104
  ostemplate   = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  unprivileged = true
  password     = var.pic_lxc_root_password

  cores    = 2
  cpulimit = 0
  memory   = 6144
  swap     = 512

  # Required for Docker (server, Postgres, Redis, ML service) to run inside
  # an unprivileged LXC.
  features {
    nesting = true
    keyctl  = true
  }

  rootfs {
    storage = "local"
    size    = "20G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = var.pic_ip
    gw     = var.gw_ip
  }

  lifecycle {
    ignore_changes = [
      description,
      onboot,
      password,
      tags,
      ostemplate,
      rootfs,
      network,
      cpulimit,
      cmode,
      start,
      target_node,
    ]
  }
}

# pic - Immich as a VM (replaces the LXC above; see README.md).
# Cloned from a Debian 12 cloud-init template (scripts/create-template.sh).
# Cloud-init is Proxmox-native (user, ssh key, IP) - no snippets storage and
# no secrets involved. SMB credentials are entered inside the VM by setup.sh.
resource "proxmox_vm_qemu" "pic_vm" {
  target_node = "pve"
  name        = "pic"
  vmid        = var.pic_vm_id
  clone       = var.pic_vm_template
  full_clone  = true
  os_type     = "cloud-init"

  machine            = "q35"
  scsihw             = "virtio-scsi-single"
  agent              = 1
  start_at_node_boot = true
  memory             = var.pic_vm_memory

  cpu {
    cores = var.pic_vm_cores
    type  = "host" # Immich ML needs AVX; the default x86-64-v2-AES model lacks it
  }

  ciuser    = var.pic_vm_user
  sshkeys   = var.pic_ssh_public_key
  ipconfig0 = "ip=${var.pic_vm_ip},gw=${var.gw_ip}"

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage  = var.pic_vm_storage
          size     = "${var.pic_vm_disk_gb}G"
          iothread = true
          discard  = true
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = var.pic_vm_storage
        }
      }
    }
  }

  boot = "order=scsi0"

  lifecycle {
    ignore_changes = [
      description,
      tags,
      clone,
      full_clone,
      network, # MAC is assigned on create
    ]
  }
}
