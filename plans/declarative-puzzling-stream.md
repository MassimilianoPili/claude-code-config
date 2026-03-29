# Piano: Aumento Swap da 8GB a 16GB

## Contesto

La swap attuale (`lv_swap`, 8GB su SSD `vg_ssd`) è al 90% (7.2 GiB usati).
Con solo 1.8 GiB RAM disponibile, un `swapoff` causerebbe OOM.
Il VG ha 12.73 GiB liberi → si aggiunge un secondo LV swap in parallelo.

## Approccio: Secondo LV swap (safe, no swapoff)

Crea `lv_swap2` (8GB) affianco a quello esistente → swap totale: 16GB.

## Passi

### 1. Creare il nuovo LV
```bash
sudo lvcreate -L 8G -n lv_swap2 vg_ssd
```

### 2. Formattare come swap
```bash
sudo mkswap /dev/vg_ssd/lv_swap2
```

### 3. Attivare immediatamente
```bash
sudo swapon /dev/vg_ssd/lv_swap2
```

### 4. Verificare
```bash
swapon --show
free -h
```

### 5. Aggiungere a /etc/fstab (persistenza al reboot)
```bash
echo '/dev/vg_ssd/lv_swap2 none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 6. Verificare fstab
```bash
sudo swapon --all --verbose   # simula mount fstab per swap
grep swap /etc/fstab
```

## File coinvolti
- `/etc/fstab` — aggiunta di una riga

## Verifica finale
```bash
free -h        # swap totale deve mostrare ~16G
swapon --show  # due device: /dev/dm-2 (8G) + nuovo lv_swap2 (8G)
```

## Note
- Il vecchio `lv_swap` resta intatto e attivo durante tutta la procedura
- Priorità swap identica (-2) → il kernel usa entrambi i device in parallelo (interleaving)
- Per uniformità futura: al prossimo reboot con meno carico, si può fare swapoff del vecchio + lvextend + mkswap + swapon per tornare a un unico LV da 16G (opzionale)
