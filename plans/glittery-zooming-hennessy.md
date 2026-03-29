# Piano: Pulizia spazio disco root (/)

## Contesto

La partizione root (`/dev/mapper/vg_ssd-lv_root`, 30G) è al 100% con 0 byte disponibili.
Questo blocca operazioni normali (es. Claude Code non riesce a creare session-env).
Le partizioni `/data` (273G liberi) e `/var` (28G liberi) sono OK.

## Diagnosi

Principali consumatori su `/`:

| Percorso | Size | Tipo |
|----------|------|------|
| `/opt/android-sdk` | 5.4G | Android SDK (non usato) |
| `~/.cache/JetBrains` | 3.6G | Cache IDE JetBrains |
| `~/.gradle/caches` | 2.8G | Cache Gradle (ricostruibile) |
| `~/.cache/ms-playwright` | 2.5G | Browser binaries Playwright |
| `~/.android/` | 1.4G | Android emulator AVD (non usato) |
| `~/.npm` | 441M | Cache npm |
| `~/.djl.ai` | 438M | Modelli Deep Java Library |
| `~/.cache/go-build` | 358M | Build cache Go |
| `~/.gradle/wrapper` | 145M | Distribuzioni Gradle wrapper |
| `/tmp/*` | 830M | File temporanei |
| `/opt/az` | 639M | Azure CLI |

## Piano di esecuzione

### Fase 1 — Pulizia sicura (cache ricostruibili, ~12.5G)

```bash
# Cache JetBrains (non installato come IDE, solo cache residua)
rm -rf ~/.cache/JetBrains

# Playwright browser binaries (riscaricabili con: npx playwright install)
rm -rf ~/.cache/ms-playwright

# Go build cache
rm -rf ~/.cache/go-build

# Gradle caches + wrapper distributions
rm -rf ~/.gradle/caches ~/.gradle/wrapper

# npm cache
rm -rf ~/.npm

# Deep Java Library models
rm -rf ~/.djl.ai

# File temporanei
rm -rf /tmp/*
```

### Fase 2 — Rimozione software non usato (~6.8G)

```bash
# Android SDK (nessun dev Android su questo server)
sudo rm -rf /opt/android-sdk

# Android home directory (AVD emulator + cache)
rm -rf ~/.android
```

### Fase 3 — Symlink preventivi (opzionale, per il futuro)

Se lo spazio torna a scarseggiare, spostare directory pesanti ricostruibili su HDD con symlink:

```bash
# Esempio: spostare .gradle su HDD
mv ~/.gradle /data/massimiliano/.gradle
ln -s /data/massimiliano/.gradle ~/.gradle

# Esempio: spostare .m2 (Maven) su HDD
mv ~/.m2 /data/massimiliano/.m2
ln -s /data/massimiliano/.m2 ~/.m2
```

I programmi seguono i symlink trasparentemente — zero impatto funzionale, solo I/O leggermente più lento (HDD vs SSD).

**NON spostare ora** — con ~19G recuperati la root avrà ampio margine.

### Totale recuperabile

- **Fase 1 + 2**: ~19.3G → root da 28G/30G (93%) a ~9G/30G (30%)
- `/opt` resta intatto (all'occorrenza: move + symlink su HDD)

## Verifica

```bash
# Dopo la pulizia, verificare spazio recuperato
df -h /

# Test che Claude Code funzioni
# (la session-env si deve creare senza ENOSPC)
```
