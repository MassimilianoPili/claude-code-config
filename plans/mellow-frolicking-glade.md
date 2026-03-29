# Piano: Efficientamento MEMORY.md

## Contesto

Il MEMORY.md è cresciuto a 146 righe con ridondanze rispetto a CLAUDE.md. Le linee dopo la 200 vengono troncate dal sistema, quindi la concisione è critica. Inoltre `security.md` è referenziato ma non esiste.

## Analisi ridondanze

| Sezione | Righe | Problema |
|---------|-------|----------|
| Sicurezza e Autenticazione | 20 | Tabella client Keycloak + JWT Gateway duplicata da CLAUDE.md |
| Claude Code Hooks | 22 | Tabella 13 hook + bug noti — tutto in CLAUDE.md |
| Linguaggi e Runtime | 24 | Tabella dettagliata, linter/utility separati, note lunghe |
| code-server | 13 | Dettagli persistenza ridondanti |
| Dashboard Home | 7 | Dettagli layout in CLAUDE.md |
| Preference Sort API | paragrafo lungo | Troppo dettaglio implementativo per un file memory |

Link rotto: `[security.md](security.md)` — il file non esiste.

## Modifiche

File: `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md`

1. **Sicurezza**: rimuovere tabella client (è in CLAUDE.md), tenere solo: pattern auth (3 tipi), JWT Gateway (1 riga), Visitor read-only (1 riga), confini rete (1 riga). Rimuovere link a security.md inesistente.

2. **Preference Sort API**: compattare a 1-2 righe (path, tech, dir). Rimuovere dettagli algoritmici.

3. **Claude Code Hooks**: rimuovere tabella completa (è in CLAUDE.md) e bug noti corretti (storico, non utile). Tenere solo: directory, conteggio hook, audit log path, e le 3 categorie funzionali (security/formatting/lifecycle).

4. **Linguaggi e Runtime**: compattare tabella (rimuovere npm separato, merge linter in una riga), rimuovere sezione "Client DB containerizzati" (già ovvio da CLAUDE.md), accorciare note.

5. **code-server**: rimuovere lista tool dettagliata, tenere solo: container name, mount chiave (docker socket, SSH, git), accesso, limitazione grace time.

6. **Dashboard Home**: accorciare a 3 righe max.

## Target

Da ~146 righe a ~95-100 righe, mantenendo tutte le informazioni actionable.

## Verifica

Contare le righe dopo l'edit: `wc -l MEMORY.md` — target < 105.
