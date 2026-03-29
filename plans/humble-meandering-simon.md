# Piano: Aggiungere chiave SSH su Gitea

## Contesto
L'utente vuole aggiungere la chiave SSH pubblica `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjFcGL2x4YtRkX0I2/727Fy8D5VEAbWcqnPBVY/Y6pQ massimo@Surface-laptop-3` al proprio account Gitea, per consentire push/pull SSH dal Surface Laptop 3.

## Passi

1. **Generare un token API Gitea** via CLI nel container:
   ```bash
   docker exec -u git gitea gitea admin user generate-access-token --username sol_root --token-name "temp-ssh-key-add" --scopes "write:user"
   ```

2. **Aggiungere la chiave SSH** via API REST Gitea:
   ```bash
   curl -s -X POST "http://100.86.46.84/git/api/v1/user/keys" \
     -H "Authorization: token <TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{"title":"massimo@Surface-laptop-3","key":"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjFcGL2x4YtRkX0I2/727Fy8D5VEAbWcqnPBVY/Y6pQ massimo@Surface-laptop-3"}'
   ```

3. **Verificare** che la chiave sia stata aggiunta:
   ```bash
   curl -s "http://100.86.46.84/git/api/v1/user/keys" -H "Authorization: token <TOKEN>" | jq '.[].title'
   ```

4. **Eliminare il token temporaneo** (cleanup):
   ```bash
   docker exec -u git gitea gitea admin user delete-access-token --username sol_root --token-name "temp-ssh-key-add"
   ```

## Verifica
- La chiave appare in http://100.86.46.84/git/user/settings/keys
- SSH clone/push funziona dal Surface Laptop 3
