#!/usr/bin/env bash
set -euo pipefail

# Run ONCE on the Proxmox host as root. Builds the Debian 12 cloud-init
# template that Terraform clones (var.pic_vm_template). The Telmate provider
# can neither download images nor upload cloud-init snippets, so the image
# is prepared here, with qemu-guest-agent baked in (cloud images lack it).
#
# Needs libguestfs-tools for virt-customize (apt install libguestfs-tools),
# or run the virt-customize step on another machine and copy the image over.

TEMPLATE_ID="${TEMPLATE_ID:-9000}"
TEMPLATE_NAME="${TEMPLATE_NAME:-debian-12-cloudinit}"
STORAGE="${STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
IMG=/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2

curl -fsSL -o "$IMG" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
virt-customize -a "$IMG" --install qemu-guest-agent

qm create "$TEMPLATE_ID" --name "$TEMPLATE_NAME" --machine q35 --cpu host --cores 2 --memory 2048 \
  --net0 "virtio,bridge=${BRIDGE}" --scsihw virtio-scsi-single --agent enabled=1 --ostype l26 --serial0 socket --vga serial0
qm set "$TEMPLATE_ID" --scsi0 "${STORAGE}:0,import-from=${IMG},iothread=1,discard=on"
qm set "$TEMPLATE_ID" --ide2 "${STORAGE}:cloudinit" --boot order=scsi0
qm template "$TEMPLATE_ID"
echo "Template '${TEMPLATE_NAME}' (${TEMPLATE_ID}) ready."
