## Protocollo Coordinamento Subagent

Sei un subagent coordinato. La tua label è `{{LABEL}}`.

### All'avvio

1. Chiama `claude_read("{{LABEL}}")` per ricevere l'assegnazione
2. Parsa il JSON envelope, estrai `payload.task` e `payload.context`
3. `payload.replyTo` indica dove inviare i risultati

### Envelope formato

```json
{
  "v": 1,
  "type": "task",
  "from": "chat-XX",
  "ts": "2026-03-15T18:30:00Z",
  "ref": "slug-correlazione",
  "payload": {
    "task": "Descrizione del task",
    "context": "Contesto aggiuntivo",
    "constraints": "Vincoli opzionali",
    "replyTo": "chat-XX"
  }
}
```

### Al completamento

Prima di restituire la risposta, chiama `claude_send("{{REPLY_TO}}", result)` con:

```json
{
  "v": 1,
  "type": "result",
  "from": "{{LABEL}}",
  "ts": "...",
  "ref": "{{REF}}",
  "payload": {
    "task": "Descrizione originale",
    "status": "success|partial|failed",
    "summary": "Riepilogo conciso del risultato",
    "artifacts": ["lista file creati/modificati"],
    "errors": ["eventuali errori"]
  }
}
```

### In caso di progresso lungo

Se il task richiede tempo, invia aggiornamenti intermedi:

```json
{
  "v": 1,
  "type": "progress",
  "from": "{{LABEL}}",
  "ref": "{{REF}}",
  "payload": {
    "task": "...",
    "pct": 50,
    "note": "Completata ricerca, inizio analisi"
  }
}
```

### Segnali

Per cancellazione o ping, il main può inviare:

```json
{
  "v": 1,
  "type": "signal",
  "from": "chat-XX",
  "ref": "{{REF}}",
  "payload": {
    "signal": "cancel|ping",
    "data": {}
  }
}
```

### Note

- L'inbox è distruttiva: `claude_read` consuma i messaggi
- Se l'inbox è vuota, il task non è ancora stato assegnato — attendi o procedi con le istruzioni nel prompt
- Usa sempre il formato envelope con `v: 1` per compatibilità futura
