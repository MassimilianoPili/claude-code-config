# RAID1 Mirror — WD Blue 4TB × 2

## Context

SDC e SDD sono 2 WD Blue 4TB identici, comprati per fare mirror ma mai configurati.
SDC è montato su `/mnt/hdd` con ~27 GB di dati (restic, OpenCloud, OpenAlex).
SDD è NTFS vuoto, non montato. Nessun RAID attivo.

L'utente vuole: RAID1 mdadm su SDC+SDD, backup restic diretto sul RAID.
Il path `/mnt/hdd` resta invariato → nessuna modifica a restic-backup, OpenCloud, o altri servizi.

## Piano

### Fase 1 — Prepara SDD (zero downtime, disco non in uso)

```bash
sudo wipefs -a /dev/sdd
sudo parted /dev/sdd mklabel gpt
sudo parted /dev/sdd mkpart primary ext4 0% 100%
sudo parted /dev/sdd set 1 raid on
```

### Fase 2 — Crea RAID1 degradato (solo SDD, zero downtime)

```bash
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdd1 missing
sudo mkfs.ext4 -L hdd-raid /dev/md0
sudo mkdir -p /mnt/raid
sudo mount /dev/md0 /mnt/raid
```

### Fase 3 — Copia dati (servizi attivi su SDC)

```bash
sudo rsync -aHAX --progress /mnt/hdd/ /mnt/raid/
```

~27 GB, pochi minuti.

### Fase 4 — Swap mount (~2 min downtime)

```bash
# Stop servizi che scrivono su /mnt/hdd
docker compose -f /data/massimiliano/opencloud/docker-compose.yml \
  -f /data/massimiliano/opencloud/deployments/external-proxy/opencloud.yml \
  -f /data/massimiliano/opencloud/deployments/custom/sol.yml down

# Delta finale
sudo rsync -aHAX --delete /mnt/hdd/ /mnt/raid/

# Swap
sudo umount /mnt/hdd
sudo umount /mnt/raid
sudo mount /dev/md0 /mnt/hdd

# Riavvia
docker compose -f /data/massimiliano/opencloud/docker-compose.yml \
  -f /data/massimiliano/opencloud/deployments/external-proxy/opencloud.yml \
  -f /data/massimiliano/opencloud/deployments/custom/sol.yml up -d
```

### Fase 5 — Aggiungi SDC al RAID (rebuild in background)

```bash
sudo wipefs -a /dev/sdc
sudo parted /dev/sdc mklabel gpt
sudo parted /dev/sdc mkpart primary ext4 0% 100%
sudo parted /dev/sdc set 1 raid on
sudo mdadm --add /dev/md0 /dev/sdc1
```

Rebuild: ~3-5 ore in background, servizi operativi.

### Fase 6 — Persistenza

```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
# Aggiorna fstab: UUID di sdc1 → /dev/md0
```

## Nessuna modifica applicativa

- `restic-backup`: path `/mnt/hdd/restic-backups` invariato
- `restic-check`: invariato
- `OpenCloud`: `OC_DATA_DIR=/mnt/hdd/opencloud-data` invariato
- `dashboard-api`: invariato

## Verifica

1. `cat /proc/mdstat` → md0 RAID1 [sdc1, sdd1] clean
2. `df -h /mnt/hdd` → 3.6T, da /dev/md0
3. `/data/massimiliano/shell-scripts/bin/restic-backup` → exit 0
4. `curl localhost:7681/metrics/backups` → status ok
5. `docker logs opencloud --tail 5` → healthy
