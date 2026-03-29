# Piano: Ridimensionare /var e estendere /root (LVM)

## Contesto

La partizione root (`/`) ha solo 30 GB su SSD ed è al 64% (18 GB usati). `/var` ha 60 GB ma ne usa meno di 1 GB — spreco enorme. L'utente vuole ridurre `/var` e dare lo spazio a root, dove risiedono `/home`, `/opt` (JetBrains ~10 GB, Android SDK ~5 GB) e le cache.

## Layout attuale

```
SSD /dev/sdb (111.8 GB):
├─ sdb1: 1 GB EFI
└─ sdb2: 110.7 GB (PV vg_ssd)
    ├─ lv_root:  30 GB → /     (ext4, 18 GB usati)
    ├─ lv_var:   60 GB → /var  (ext4, <1 GB usato)
    ├─ lv_swap:   8 GB → swap
    └─ free:    ~12 GB
```

Docker Root Dir: `/data/docker` (HDD) — non su `/var`.
Containerd overlay layers: `/var/lib/containerd/` — richiede Docker fermo per smontare `/var`.

## Target

```
lv_var:  15 GB (da 60 GB — più che sufficiente per log, cache, containerd)
lv_root: 87 GB (30 + 45 recuperati da var + 12 liberi nel VG)
```

## Procedura (recovery mode via GRUB)

### 1. Reboot in recovery mode
```bash
sudo reboot
```
Al GRUB: **Advanced options for Ubuntu** → **recovery mode** → **root shell**

### 2. Verificare che /var sia smontato
```bash
mount | grep /var
# Se montato:
umount /var
```

### 3. Controllare il filesystem di /var
```bash
e2fsck -f /dev/vg_ssd/lv_var
```

### 4. Ridurre il filesystem ext4 a 15 GB
```bash
resize2fs /dev/vg_ssd/lv_var 15G
```

### 5. Ridurre il logical volume a 15 GB
```bash
lvreduce -L 15G /dev/vg_ssd/lv_var
```

### 6. Estendere root con tutto lo spazio libero
```bash
lvextend -l +100%FREE /dev/vg_ssd/lv_root
resize2fs /dev/vg_ssd/lv_root
```

### 7. Rimontare e riavviare
```bash
mount /var
reboot
```

## Verifica post-reboot

```bash
df -h / /var
# Atteso: / ~87 GB, /var ~15 GB
sudo lvs vg_ssd
# Atteso: lv_root ~87G, lv_var 15G, lv_swap 8G
docker ps
# Tutti i container devono tornare su (restart: unless-stopped)
```

## Rischi e mitigazioni

- **Rischio**: `resize2fs` fallisce → il filesystem resta intatto, nessun dato perso
- **Rischio**: dimensione LV < dimensione FS → **sempre ridurre FS prima, poi LV** (l'ordine nel piano è corretto)
- **Downtime**: ~3-5 minuti (reboot + operazioni + reboot)
- **Rollback**: se qualcosa va storto, basta estendere lv_var a 60G e resize2fs senza parametro di dimensione
