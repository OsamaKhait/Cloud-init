# VM Cloud-Init avec QEMU (macOS)

## Objectifs
- Démarrer une VM Ubuntu Cloud (via QEMU) sur macOS.
- Restreindre l’accès SSH **uniquement par clé** (pas de mot de passe).
- Interdire `root` en SSH.
- Créer un utilisateur non-root avec **/bin/bash** comme shell par défaut.
- Fournir deux scripts : préparation et lancement.

---

## Scripts

### 1. `prep_cloud_vm.sh`
Ce script :
- Télécharge une image Ubuntu cloud (arm64 sur Mac Apple Silicon).
- Crée un disque qcow2 basé sur l’image.
- Génère un ISO cloud-init (`seed.iso`) avec :
  - SSH par clé uniquement.
  - Root interdit.
  - Utilisateur `camarade` avec `/bin/bash`.

### 2. `run_and_shell.sh`
Ce script :
- Lance la VM avec QEMU et accélération HVF.
- Configure un port-forward (`localhost:2222` → SSH de la VM).
- Attends que SSH soit disponible.
- Ouvre automatiquement un shell SSH sur la VM (utilisateur `camarade`).

---

## Utilisation

1. Cloner le projet :
   ```bash
   git clone <repo_url>
   cd vm-cloud
   ```

2. Donner les droits d’exécution :
   ```bash
   chmod +x prep_cloud_vm.sh run_and_shell.sh
   ```

3. Préparer l’image + cloud-init :
   ```bash
   ./prep_cloud_vm.sh
   ```

4. Lancer la VM et entrer dans le shell :
   ```bash
   ./run_and_shell.sh
   ```

---

## Ajouter un utilisateur supplémentaire

Exemple pour créer un nouvel utilisateur `etudiant1` avec une clé SSH :

```bash
sudo adduser --disabled-password --gecos "" etudiant1
sudo usermod -s /bin/bash etudiant1
sudo mkdir -p /home/etudiant1/.ssh
echo "ssh-ed25519 AAAA...etudiant1" | sudo tee /home/etudiant1/.ssh/authorized_keys
sudo chown -R etudiant1:etudiant1 /home/etudiant1/.ssh
sudo chmod 700 /home/etudiant1/.ssh
sudo chmod 600 /home/etudiant1/.ssh/authorized_keys
```

Le camarade pourra ensuite se connecter :
```bash
ssh -p 2222 etudiant1@<IP_HOTE>
```

---

## Arrêt et gestion

- Arrêt propre dans la VM :
  ```bash
  sudo poweroff
  ```

- Relancer la VM :
  ```bash
  ./run_and_shell.sh
  ```

---

## Notes
- Testé sur macOS avec QEMU (`arm64` / Apple Silicon).
- Le projet peut être adapté pour Debian, Rocky Linux ou Alpine en changeant l’URL de l’image cloud dans `prep_cloud_vm.sh`.
- Vérifiez vos réglages de pare-feu si vous voulez permettre l’accès à d’autres machines sur le réseau.




# README – Déploiement VM QEMU + Ansible + MySQL

Ce projet montre comment automatiser la configuration d’une VM Ubuntu lancée via **QEMU** (port SSH 2222) avec **Ansible**, en installant MySQL et en important un jeu de données DNS.

---

## 🧰 Pré-requis
- VM Ubuntu en marche sur `localhost:2222`
- Clé SSH valide (chargée avec `ssh-agent` ou sans passphrase)
- Ansible installé sur la machine hôte (macOS)
- Collection `community.mysql` installée

```bash
brew install ansible
ansible-galaxy collection install community.mysql
```

---

## 📁 Arborescence du projet
```
vm-cloud/
└─ ansible/
   ├─ ansible.cfg
   ├─ inventory.ini
   ├─ site.yml
   └─ roles/
      ├─ common/
      │  ├─ tasks/main.yml
      │  └─ handlers/main.yml
      └─ mysql/
         ├─ defaults/main.yml
         └─ tasks/main.yml
```

---

## ⚙️ Configuration Ansible

### `ansible.cfg`
- Définit l’inventaire local
- Active `become` par défaut
- Configure le répertoire temporaire

### `inventory.ini`
Contient la VM QEMU :
```ini
[demo]
demo-cloud ansible_host=127.0.0.1 ansible_port=2222

[demo:vars]
ansible_user=camarade
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args=-o IdentitiesOnly=yes
```

---

## 🧱 Rôles

### `common`
- Met à jour `apt`
- Installe des paquets de base (curl, git, htop, ufw…)
- Active le pare-feu UFW
- Définit le hostname
- Prépare `/opt/tools`

### `mysql`
- Installe MySQL et ses dépendances (`python3-pymysql`)
- Démarre et active MySQL
- Crée une base `dns` et un utilisateur `dnsuser`
- Télécharge un dump SQL DNS de test (gist)
- Remplace `TYPE=` → `ENGINE=` pour compatibilité MySQL 8+
- Importe le dump dans la base

---

## ▶️ Exécution
```bash
cd ansible
ansible-inventory --list --yaml   # Vérifier l’inventaire
ansible all -m ping               # Tester SSH
ansible-playbook site.yml         # Déployer Common + MySQL + Import
```

---

## ✅ Vérifications
```bash
# MySQL actif ?
ansible all -a "systemctl is-active mysql"

# Base créée ?
ansible all -m shell -a 'mysql -S /var/run/mysqld/mysqld.sock -e "SHOW DATABASES LIKE \"dns\";"' --become

# Tables importées ?
ansible all -m shell -a 'mysql -S /var/run/mysqld/mysqld.sock -D dns -e "SHOW TABLES;"' --become
```

---

## 🧰 Dépannage
- **Permission denied (publickey)** → vérifier `ssh-agent` et inventaire.
- **Python introuvable** → installer `python3` dans la VM.
- **404 dump** → corriger `mysql_dump_url`.
- **Import SQL** → bien faire les remplacements `TYPE=` → `ENGINE=`.

---

📄 **Ce README.md peut être livré au professeur comme documentation du projet.**

