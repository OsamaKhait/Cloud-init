#!/usr/bin/env bash
set -euo pipefail

### ==== CONFIGURATION ==== ###
VM_NAME="demo-cloud"
ARCH="arm64"        # "arm64" (Apple Silicon) ou "amd64" (Mac Intel)
FRIEND_USER="camarade"
SSH_PORT="2222"
RAM_MB="4096"
CPUS="4"
### ======================== ###

WD="${PWD}/${VM_NAME}"
IMG_DIR="${WD}/img"
VM_DISK="${IMG_DIR}/${VM_NAME}.qcow2"
SEED_ISO="${IMG_DIR}/seed.iso"

if [[ ! -f "${VM_DISK}" || ! -f "${SEED_ISO}" ]]; then
  echo "❌ Disque ou seed.iso manquants. Lancez d’abord ./prep_cloud_vm.sh"
  exit 1
fi

echo "➡️  Lancement de la VM (${ARCH})…"

if [[ "${ARCH}" == "arm64" ]]; then
  # ===== Firmware UEFI local (dans img/) =====
  CODE_FD="${IMG_DIR}/edk2-aarch64-code.fd"
  VARS_FD="${IMG_DIR}/edk2-aarch64-vars.fd"

  # Vérifie que le firmware existe, sinon le copie/télécharge
  if [[ ! -f "${CODE_FD}" ]]; then
    echo "➡️  Copie du firmware UEFI (code.fd)…"
    cp /opt/homebrew/share/qemu/edk2-aarch64-code.fd "${CODE_FD}"
  fi

  if [[ ! -f "${VARS_FD}" ]]; then
    echo "➡️  Téléchargement du firmware UEFI (vars.fd)…"
    curl -L https://raw.githubusercontent.com/qemu/qemu/master/pc-bios/edk2-aarch64-vars.fd \
      -o "${VARS_FD}"
  fi

  qemu-system-aarch64 \
    -machine virt,highmem=on \
    -accel hvf \
    -cpu host \
    -smp "${CPUS}" -m "${RAM_MB}" \
    -drive if=pflash,format=raw,readonly=on,file="${CODE_FD}" \
    -drive if=pflash,format=raw,file="${VARS_FD}" \
    -device virtio-net-pci,netdev=n1 \
    -netdev user,id=n1,hostfwd=tcp::${SSH_PORT}-:22 \
    -drive if=virtio,cache=writeback,file="${VM_DISK}",format=qcow2 \
    -drive if=virtio,format=raw,file="${SEED_ISO}" \
    -display none \
    -daemonize
else
  qemu-system-x86_64 \
    -accel hvf \
    -cpu host \
    -smp "${CPUS}" -m "${RAM_MB}" \
    -device virtio-net-pci,netdev=n1 \
    -netdev user,id=n1,hostfwd=tcp::${SSH_PORT}-:22 \
    -drive if=virtio,cache=writeback,file="${VM_DISK}",format=qcow2 \
    -drive if=virtio,format=raw,file="${SEED_ISO}" \
    -display none \
    -daemonize
fi

echo "➡️  Attente de la disponibilité SSH sur localhost:${SSH_PORT}…"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 -p ${SSH_PORT}"

for i in $(seq 1 120); do
  if ssh ${SSH_OPTS} ${FRIEND_USER}@127.0.0.1 "echo ok" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "✅ Connexion SSH. Ouverture du shell…"
exec ssh ${SSH_OPTS} ${FRIEND_USER}@127.0.0.1

