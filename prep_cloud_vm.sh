#!/usr/bin/env bash
set -euo pipefail

### ==== À PERSONNALISER ==== ###
VM_NAME="demo-cloud"
# "arm64" si Mac Apple Silicon (M1/M2/M3/M4). "amd64" si Mac Intel.
ARCH="arm64"
# Nom de votre camarade à créer dans la VM
FRIEND_USER="camarade"
# Votre clé publique locale à autoriser pour SSH (vous + votre camarade)
YOUR_PUBKEY="${HOME}/.ssh/id_ed25519.pub"
# Taille du disque VM (qcow2)
DISK_SIZE_GB="20"
### ========================== ###

WD="${PWD}/${VM_NAME}"
IMG_DIR="${WD}/img"
SEED_DIR="${WD}/seed"
mkdir -p "${IMG_DIR}" "${SEED_DIR}"

if [[ ! -f "${YOUR_PUBKEY}" ]]; then
  echo "❌ Clé publique introuvable: ${YOUR_PUBKEY}"
  echo "   Générez-en une: ssh-keygen -t ed25519"
  exit 1
fi

PUBKEY_CONTENT="$(cat "${YOUR_PUBKEY}")"

echo "➡️  Téléchargement image Ubuntu cloud (${ARCH})…"
case "${ARCH}" in
  amd64)
    BASE_IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ;;
  arm64)
    BASE_IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"
    ;;
  *)
    echo "❌ ARCH doit être 'amd64' ou 'arm64'"; exit 1;;
esac

BASE_IMG="${IMG_DIR}/base.img"
if [[ ! -f "${BASE_IMG}" ]]; then
  curl -L "${BASE_IMG_URL}" -o "${BASE_IMG}.tmp"
  mv "${BASE_IMG}.tmp" "${BASE_IMG}"
fi

echo "➡️  Création disque VM ${DISK_SIZE_GB}Go…"
VM_DISK="${IMG_DIR}/${VM_NAME}.qcow2"
if [[ ! -f "${VM_DISK}" ]]; then
  qemu-img create -f qcow2 -F qcow2 -b "${BASE_IMG}" "${VM_DISK}" "${DISK_SIZE_GB}G" >/dev/null
fi

echo "➡️  Génération des fichiers cloud-init…"
cat > "${SEED_DIR}/meta-data" <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

cat > "${SEED_DIR}/user-data" <<'EOF'
#cloud-config
disable_root: true
ssh_pwauth: false
package_update: true
packages:
  - bash
users:
  # Utilisateur "ubuntu" (par défaut sur Ubuntu cloud)
  - name: ubuntu
    gecos: Ubuntu
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - __REPLACE_PUBKEY__
  # Camarade demandé
  - name: __REPLACE_FRIEND__
    gecos: Camarade
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - __REPLACE_PUBKEY__
ssh:
  emit_keys_to_console: false
  allow_users: [ubuntu, __REPLACE_FRIEND__]
# UFW basique (optionnel)
#runcmd:
#  - [ bash, -lc, "ufw allow OpenSSH && ufw --force enable" ]
EOF

# Injecte les variables dans user-data
sed -i '' -e "s|__REPLACE_PUBKEY__|${PUBKEY_CONTENT//|/\\|}|g" \
          -e "s|__REPLACE_FRIEND__|${FRIEND_USER}|g" "${SEED_DIR}/user-data"

echo "➡️  Création de l’ISO NoCloud (seed.iso)…"
SEED_ISO="${IMG_DIR}/seed.iso"
# Méthode 1 : cloud-localds si dispo
if command -v cloud-localds >/dev/null 2>&1; then
  cloud-localds "${SEED_ISO}" "${SEED_DIR}/user-data" "${SEED_DIR}/meta-data"
else
  # Méthode 2 : hdiutil natif macOS
  TMPFOLDER="$(mktemp -d)"
  cp "${SEED_DIR}/user-data" "${TMPFOLDER}/user-data"
  cp "${SEED_DIR}/meta-data" "${TMPFOLDER}/meta-data"
  # label "cidata" requis par NoCloud
  hdiutil makehybrid -iso -joliet -default-volume-name cidata "${TMPFOLDER}" -o "${SEED_ISO}"
  rm -rf "${TMPFOLDER}"
fi

echo "✅ Préparation terminée.
Dossier VM : ${WD}
- Disque VM : ${VM_DISK}
- Seed ISO  : ${SEED_ISO}
- Image base: ${BASE_IMG}
- ARCH      : ${ARCH}
- User créé : ${FRIEND_USER}
"

