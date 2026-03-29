# Sprint 2: GitHub Pages Deploy + Audio SFX Procedurale

## Context

Sprint 1 completato: persistenza (SaveManager), quest log (Q), schermata completamento (10/10), bugfix tavern/visibility. Il gioco e' funzionante e live su SOL (`/rpg-godot/`).

**Problema 1**: Il gioco e' accessibile solo via SOL (Tailscale/Cloudflare). Serve un URL pubblico su GitHub Pages per il portfolio.
**Problema 2**: Il gioco e' silenzioso — nessun feedback audio. Per un RPG ispirato a Mother 3, i suoni sono fondamentali per l'esperienza.

**Repo**: `MassimilianoPili.github.io` — repo multi-progetto per GitHub Pages. Remote: `origin` (Gitea) + `github` (GitHub). Root `index.html` redirecta a `tools.massimilianopili.com`. L'export del gioco e' a `rpg-godot/export/web/`.

## Step-by-step

### Step 1: Landing page per GitHub Pages

**Creare**: `rpg-godot/index.html`

Pagina di atterraggio con meta-refresh redirect a `export/web/index.html`. Include Open Graph meta tags per condivisione social (titolo, descrizione, immagine). Il redirect e' immediato — l'utente vede il gioco in < 1 secondo.

Motivo: GitHub Pages serve `massimilianopili.github.io/rpg-godot/` → legge `rpg-godot/index.html` → redirect a `rpg-godot/export/web/index.html` dove vive il gioco.

### Step 2: .nojekyll + .gitignore

**Creare**: `.nojekyll` (file vuoto alla root del repo — disabilita Jekyll che ignora file con `_` o `.`)

**Modificare**: `.gitignore` — aggiungere:
```
rpg-godot/.godot/
rpg-godot/assets/mother3_raw/
```

### Step 3: AudioManager — SFX procedurale

**Creare**: `rpg-godot/scripts/audio_manager.gd` (nuovo autoload)

Genera tutti i suoni via `AudioStreamWAV` con dati PCM. Nessun file audio esterno — zero peso aggiuntivo nel build.

5 suoni:
- **Dialogue beep** — square wave 440Hz × 50ms con envelope decay (stile Mother 3 typewriter)
- **Quest jingle** — arpeggio ascendente C5-E5-G5-C6 (triangle wave, ~400ms)
- **Portal whoosh** — rumore bianco filtrato con sweep discendente (~300ms)
- **NPC pop** — sine wave con pitch drop 880→220Hz (~60ms)
- **Footstep** — burst di rumore breve (~30ms, volume basso -14dB)

5 `AudioStreamPlayer` separati per permettere overlap.

### Step 4: Registrare AudioManager come autoload

**Modificare**: `rpg-godot/project.godot`

Aggiungere dopo CompletionScreen:
```
AudioManager="*res://scripts/audio_manager.gd"
```

9 autoload totali: GameManager, SaveManager, DialogueManager, QuestManager, TransitionManager, HUD, QuestLog, CompletionScreen, AudioManager.

### Step 5: Integrare audio nei script esistenti

**`scripts/dialogue_box.gd`** — beep ogni 3 caratteri del typewriter:
- Aggiungere `var _last_beep_char: int = 0` e `const BEEP_INTERVAL: int = 3`
- In `_process()`: se `new_chars > _last_beep_char + BEEP_INTERVAL` → `AudioManager.play_dialogue_beep()`
- In `display()`: reset `_last_beep_char = 0`

**`scripts/quest_manager.gd:38`** — jingle dopo `quest_completed.emit()`:
- Aggiungere: `AudioManager.play_quest_complete()`

**`scripts/transition_manager.gd:22`** — whoosh all'inizio della transizione:
- Aggiungere: `AudioManager.play_portal_whoosh()` prima del fade-out

**`scripts/npc.gd:27`** — pop all'inizio dell'interazione:
- Aggiungere: `AudioManager.play_npc_pop()` prima della scelta del dialogo

**`scripts/player.gd:55`** — footstep al cambio frame dell'animazione walk:
- In `_physics_process()`, quando `_anim_frame` cambia a 0 o 2: `AudioManager.play_footstep()`

### Step 6: Re-export + deploy SOL

```bash
cd /data/massimiliano/Vari/MassimilianoPili.github.io/rpg-godot
godot --headless --import
godot --headless --export-release "Web" export/web/index.html
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

### Step 7: Commit + push GitHub Pages

```bash
cd /data/massimiliano/Vari/MassimilianoPili.github.io
git add .nojekyll .gitignore rpg-godot/
git commit -m "Sprint 2: GitHub Pages deploy + procedural audio SFX"
git push origin main
git push github main
```

GitHub Pages si attiva automaticamente per i repo `*.github.io` (o va abilitato in Settings > Pages > Source: main / root).

### Step 8: Aggiornare PIANO.md

Segnare come completati: Fase 5, Fase 6 (parziale), Fase 7 (SFX — BGM rimandato), Fase 11 (deploy).

## File da creare/modificare

| File | Azione |
|------|--------|
| `rpg-godot/scripts/audio_manager.gd` | **Creare** — SFX procedurale (5 suoni, ~160 righe) |
| `rpg-godot/index.html` | **Creare** — Landing page OG + redirect |
| `.nojekyll` | **Creare** — file vuoto |
| `.gitignore` | **Modificare** — ignore .godot/ e mother3_raw/ |
| `rpg-godot/project.godot` | **Modificare** — autoload AudioManager |
| `rpg-godot/scripts/dialogue_box.gd` | **Modificare** — beep typewriter |
| `rpg-godot/scripts/quest_manager.gd` | **Modificare** — jingle quest |
| `rpg-godot/scripts/transition_manager.gd` | **Modificare** — whoosh portale |
| `rpg-godot/scripts/npc.gd` | **Modificare** — pop interazione |
| `rpg-godot/scripts/player.gd` | **Modificare** — footstep opzionale |

## Autoload order (aggiornato)

```
GameManager       → stato globale
SaveManager       → persistenza
DialogueManager   → sistema dialoghi
QuestManager      → tracking quest
TransitionManager → fade transizioni
HUD               → overlay zona/quest
QuestLog          → diario quest (Q)
CompletionScreen  → schermata finale
AudioManager      → SFX procedurale
```

## Verifica

1. Aprire `http://100.86.46.84/rpg-godot/` → gioco funziona con audio
2. Muoversi → footstep sottili a ogni passo
3. Parlare con NPC → pop di interazione + beep typewriter durante il dialogo
4. Completare quest → jingle ascendente
5. Entrare in un portale → whoosh durante la transizione
6. Aprire `https://massimilianopili.github.io/rpg-godot/` → landing page → redirect al gioco
7. Condividere URL su social → preview con titolo "Portfolio Interattivo" e immagine
