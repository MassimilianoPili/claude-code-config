# Plan: Supporto Immagini Incollate nella Dashboard Chat

## Context

La dashboard chat (`/claude/v1/messages`) supporta solo testo. L'utente vuole poter **incollare immagini** (Ctrl+V / Cmd+V) nella chat, visualizzare una preview, e inviarle a Claude che le analizzi. La CLI `claude` supporta input multimodale via `--input-format stream-json`.

## File da modificare

1. **`/data/massimiliano/proxy/home/index.html`** — frontend: paste handler, preview, content blocks
2. **`/data/massimiliano/Vari/claude-proxy/main.go`** — backend: Message.Content flessibile, stdin input per immagini

## Stato attuale

- **Frontend**: `sendMessage()` invia `{role, content: string}` come testo puro. Nessun paste handler.
- **Backend**: `Message.Content` e' `string`. Usa `-p prompt` (testo) + `--output-format stream-json`. Gira sull'**host** come systemd service (`claude-proxy.service`, PID 6704, porta 8091). Ha accesso alla CLI `claude` dell'host.
- **CLI**: `claude --input-format stream-json` accetta NDJSON con content blocks multimodali (testo + immagini base64) via stdin.

---

## Parte 1: Frontend (`index.html`)

### 1a. CSS — stile preview immagine (~10 righe)

```css
.chat-image-preview { /* container preview sotto l'input */ }
.chat-image-preview img { max-height:120px; border-radius:8px; }
.chat-image-preview .remove-btn { /* X per rimuovere */ }
.msg-user img { max-width:100%; border-radius:8px; margin-top:4px; }
```

### 1b. HTML — container preview

Aggiungere un `<div id="image-preview" class="chat-image-preview hidden"></div>` dentro `.chat-input-area`, sopra il textarea.

### 1c. JS — paste handler e invio (~60 righe)

1. **Variabile globale** `var pendingImage = null;` (oggetto `{base64, mediaType}`)

2. **Paste event** su `#chat-input`:
   - `e.clipboardData.items` → cercare item con `type.startsWith('image/')`
   - Leggere come `FileReader.readAsDataURL()` → estrarre base64 e mediaType
   - Salvare in `pendingImage` e mostrare preview

3. **Drag & drop** (bonus): stesso handler per `dragover`/`drop`

4. **`sendMessage()` modificata**:
   - Se `pendingImage` e' presente, costruire content come **array di blocchi**:
     ```js
     content = [
       {type: "image", source: {type: "base64", media_type: pendingImage.mediaType, data: pendingImage.base64}},
       {type: "text", text: text || "Descrivi questa immagine"}
     ]
     ```
   - Se no immagine, content resta stringa (retrocompatibile)
   - Aggiungere a `conversationHistory` e inviare

5. **`appendMessage('user', content)` modificata**:
   - Se content e' array, renderizzare testo + `<img src="data:...">` nel bubble
   - Se content e' stringa, comportamento attuale

6. **`loadConversation()` / history**: gestire content sia come stringa che come array (retrocompat con chat salvate)

7. **Rimuovere preview**: click sulla X, o dopo invio messaggio

### 1d. Limite dimensione

- Max 5MB per immagine (base64 ~6.6MB encoded). Check nel paste handler, errore se troppo grande.
- Claude supporta fino a ~20MB ma per UX e memoria 5MB e' ragionevole.

---

## Parte 2: Backend (`main.go`)

### 2a. Tipo Message flessibile

Cambiare `Content` da `string` a `json.RawMessage`:

```go
type Message struct {
    Role      string          `json:"role"`
    Content   json.RawMessage `json:"content"`    // string OR []ContentBlock
    Timestamp string          `json:"timestamp,omitempty"`
}
```

### 2b. Helper per estrarre testo

```go
// contentText extracts text from Content (string or []ContentBlock).
func contentText(raw json.RawMessage) string { ... }

// hasImages returns true if Content contains image blocks.
func hasImages(raw json.RawMessage) bool { ... }
```

### 2c. `formatConversation()` — solo testo

Continuare a usare `contentText()` per estrarre il testo da ogni messaggio (retrocompatibile).

### 2d. Invocazione CLI — due path

**Path A (solo testo, attuale)**: `-p prompt` come adesso. Nessuna modifica.

**Path B (con immagini)**: quando `hasImages(lastUserMsg.Content)`:
1. Rimuovere `-p prompt` dagli args
2. Aggiungere `--input-format stream-json` agli args
3. Preparare l'ultimo messaggio utente come NDJSON su stdin:
   ```json
   {"type":"user_message","content":[{"type":"image","source":{"type":"base64","media_type":"image/png","data":"..."}},{"type":"text","text":"Descrivi"}]}
   ```
4. Per i messaggi precedenti (contesto), prepend come testo nel system prompt o nell'ultimo messaggio testuale

**Nota**: `--input-format stream-json` richiede che il prompt arrivi via stdin, non via `-p`. I due flag sono mutualmente esclusivi.

### 2e. Persistenza conversazioni

`Message.Content` e' gia' `json.RawMessage` → si serializza/deserializza correttamente sia come stringa che come array. Nessuna modifica necessaria alla persistenza.

### 2f. Build e restart

```bash
cd /data/massimiliano/Vari/claude-proxy
go build -o claude-proxy-bin .
systemctl --user restart claude-proxy
```

---

## Ordine di implementazione

1. Backend: tipo `Message.Content` → `json.RawMessage` + helpers
2. Backend: path B con `--input-format stream-json` per messaggi con immagini
3. Backend: build e test con curl (invio JSON con image block)
4. Frontend: paste handler + preview UI
5. Frontend: `sendMessage()` multimodale + `appendMessage()` con immagini
6. Frontend: recreate nginx + test E2E nel browser

## Stato implementazione (IN PROGRESS)

**Completato**:
1. Backend: `Message.Content` → `json.RawMessage` + helpers (`contentText`, `hasImages`, `textContent`)
2. Backend: Path B con `--input-format stream-json` per messaggi con immagini
3. Frontend: paste handler + preview UI + `sendMessage()` multimodale + `renderUserContent()`
4. Frontend: nginx ricreato

**Bug attuale**: L'utente invia immagine + testo, la UI mostra il messaggio e il typing indicator, ma Claude non risponde. I log del proxy mostrano ZERO richieste ricevute dopo il restart → il browser potrebbe aver cachato il vecchio JS, oppure la fetch fallisce silenziosamente.

**Prossimi passi (debugging)**:
1. Rebuild binary con debug logging gia' aggiunto a main.go
2. Restart claude-proxy service
3. Hard refresh del browser (Ctrl+Shift+R)
4. Retry invio immagine e controllare log
5. Se la richiesta arriva ma il CLI fallisce: verificare formato stream-json
6. Se la richiesta NON arriva: ispezionare console browser per errori JS/fetch

## Verifica finale

1. `go build -o claude-proxy-bin .` senza errori
2. `curl` con payload JSON contenente image block → risposta streaming
3. Aprire dashboard, incollare immagine → preview visibile
4. Inviare → Claude descrive l'immagine → risposta in streaming
5. Ricaricare pagina → history mostra l'immagine nel messaggio
6. Inviare solo testo → funziona come prima (retrocompatibilita')
