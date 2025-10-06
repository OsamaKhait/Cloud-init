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
