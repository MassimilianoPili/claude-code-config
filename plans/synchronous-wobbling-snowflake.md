# Fix File Manager: APK download + folder download as ZIP + caching

## Context

Il file manager (`go-filemanager`) ha tre problemi:

1. **APK scaricati come .zip** — FATTO
2. **Nessun download cartelle** — FATTO (backend + frontend)
3. **Cache impedisce aggiornamento JS** — Il browser e Cloudflare CDN cachano i file JS perché `Cache-Control: public, max-age=3600` (`embed.go:58`) e gli ES module imports non hanno cache-bust

## Piano

### Fix 1: MIME type corretto per .apk (e altre estensioni mancanti)

**File**: `internal/fileops/operations.go` — funzione `detectMime()` (riga 208)

Aggiungere una mappa custom di MIME type mancanti da Go stdlib, e settare `Content-Type` esplicitamente nel handler di download PRIMA di `http.ServeFile`.

**File**: `internal/fileops/handler.go` — funzione `List()` (riga 36-40)

Attualmente:
```go
w.Header().Set("Content-Disposition", "attachment; filename=\""+filepath.Base(fullPath)+"\"")
http.ServeFile(w, r, fullPath)
```

Cambiare in:
```go
w.Header().Set("Content-Disposition", "attachment; filename=\""+filepath.Base(fullPath)+"\"")
w.Header().Set("Content-Type", detectMime(filepath.Base(fullPath)))
http.ServeFile(w, r, fullPath)
```

In `detectMime`, aggiungere fallback custom prima del generico `application/octet-stream`:

```go
var customMimeTypes = map[string]string{
    ".apk":  "application/vnd.android.package-archive",
    ".ipa":  "application/octet-stream",
    ".wasm": "application/wasm",
    ".mjs":  "text/javascript",
    ".toml": "application/toml",
    ".yaml": "application/x-yaml",
    ".yml":  "application/x-yaml",
}
```

NOTA: `http.ServeFile` rispetta il `Content-Type` se già settato nell'header — non lo sovrascrive.

### Fix 2: Download cartelle come ZIP

**Nessuna dipendenza esterna** — Go stdlib ha `archive/zip` e `io/fs`.

#### Backend

**File**: `internal/fileops/handler.go` — nuovo metodo `DownloadFolder()`

```go
func (h *FileHandler) DownloadFolder(w http.ResponseWriter, r *http.Request) {
    userPath := r.PathValue("path")
    info, fullPath, err := GetFileInfo(h.root, userPath)
    // ... validazione: deve essere directory ...

    folderName := filepath.Base(fullPath)
    w.Header().Set("Content-Type", "application/zip")
    w.Header().Set("Content-Disposition", `attachment; filename="`+folderName+`.zip"`)

    zw := zip.NewWriter(w)
    defer zw.Close()

    filepath.WalkDir(fullPath, func(path string, d fs.DirEntry, err error) error {
        // ... crea entry zip con path relativo ...
        // Streaming: scrive direttamente su http.ResponseWriter
    })
}
```

Streaming = niente buffer in memoria, anche cartelle grandi funzionano.

**File**: `main.go` — nuova route

```go
mux.HandleFunc("GET /api/download-folder/{path...}", authHandler.RequireAuth(fileHandler.DownloadFolder))
```

#### Frontend

**File**: `web/static/js/api.js` — nuova funzione

```js
export function downloadFolderURL(path) {
    return `${B}/api/download-folder/${path.replace(/^\/+/, '')}`;
}
```

**File**: `web/static/js/contextMenu.js` — aggiungere "Download as ZIP" per le directory

```js
if (entry.type === 'directory') {
    items.push({ label: 'Download as ZIP', icon: '⬇', action: callbacks.onDownloadFolder });
}
```

**File**: `web/static/js/app.js` — nel `handleEntryAction`, aggiungere callback

```js
onDownloadFolder: () => downloadFolder(path),
```

E la funzione:
```js
async function downloadFolder(path) {
    const a = document.createElement('a');
    a.href = api.downloadFolderURL(path);
    a.click();
}
```

### Supporto bulk download (selezione multipla)

Aggiungere anche un bottone "Download" nella bulk action bar, che scarichi gli item selezionati come ZIP.

**Backend**: nuovo endpoint `POST /api/bulk/download` che accetta `{ "paths": [...] }` e produce un ZIP.

**Frontend**: bottone nella bulk bar (accanto a Move e Delete) + chiamata.

### File da modificare (riepilogo)

| File | Modifica |
|------|----------|
| `internal/fileops/operations.go` | Mappa custom MIME + usarla in `detectMime()` |
| `internal/fileops/handler.go` | Set Content-Type esplicito nel download + nuovo `DownloadFolder()` + `BulkDownload()` |
| `main.go` | 2 nuove route: `GET /api/download-folder/{path...}`, `POST /api/bulk/download` |
| `web/static/js/api.js` | `downloadFolderURL()` + `bulkDownloadURL()` |
| `web/static/js/contextMenu.js` | "Download as ZIP" per directory |
| `web/static/js/app.js` | `downloadFolder()` + callback + bulk download button handler |

### Fix 3: Cache-Control per file statici

**File**: `web/embed.go` (riga 58)

Problema: `Cache-Control: public, max-age=3600` fa cachare i JS per 1h sia nel browser che su Cloudflare. Gli import ES module (`import * from './contextMenu.js'`) non ricevono il `?v=` cache-bust che è solo nel tag `<script>` dell'HTML.

Fix: cambiare in `no-cache` che forza la rivalidazione ad ogni request. Con file embedded, `http.FileServer` usa automaticamente `ETag` + `Last-Modified`, quindi il browser fa una request condizionale e riceve `304 Not Modified` (pochi byte). Nessun impatto prestazionale reale, ma i file nuovi vengono sempre visti.

```go
// Da:
w.Header().Set("Cache-Control", "public, max-age=3600")
// A:
w.Header().Set("Cache-Control", "no-cache")
```

### Verifica

1. Build: `docker compose build --no-cache` (dalla dir go-filemanager)
2. Deploy: `docker compose up -d`
3. Test manuale:
   - Aprire /files/browse, click destro su cartella → deve mostrare "Download as ZIP"
   - Scaricare un .apk → estensione .apk mantenuta
   - Selezionare più item → bottone "Download ZIP" nella bulk bar
