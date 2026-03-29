# Piano: Connessione SOL ↔ Gaia via LAN diretta su Windows

## Context

Gaia (GPU server, RTX 3090) è dual-boot Ubuntu/Windows. Il cavo Ethernet collega **direttamente** SOL e Gaia (point-to-point, niente switch). Su Linux lato SOL è già configurato `enp2s0` con IP `10.0.0.1/24` (stato UP, IP forwarding attivo). SOL esce su internet via WiFi `wlp3s0` (192.168.1.105, gateway 192.168.1.1).

**Obiettivi**:
1. Accesso SSH da SOL a Gaia-Windows via LAN diretta
2. Gaia-Windows naviga su internet attraverso SOL (NAT masquerade)

## Stato attuale

- **SOL** (`enp2s0`): `10.0.0.1/24` — UP, `ip_forward=1`
- **SOL** internet: `wlp3s0` → `192.168.1.1` (WiFi)
- **Gaia Windows**: cavo collegato, accesso fisico disponibile ora
- NAT masquerade: da verificare/configurare

## Step 1 — IP statico su Gaia-Windows

Su Gaia, **PowerShell come Amministratore**:

```powershell
# Trovare l'interfaccia Ethernet
Get-NetAdapter | Format-Table Name, InterfaceDescription, Status

# Assegnare IP statico + gateway SOL + DNS
# (sostituire "Ethernet" col nome trovato sopra)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.0.2 -PrefixLength 24 -DefaultGateway 10.0.0.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8,1.1.1.1

# Verificare link con SOL
ping 10.0.0.1
```

## Step 2 — NAT masquerade su SOL

Su SOL (serve sudo interattivo):

```bash
# Abilitare NAT: traffico da 10.0.0.0/24 esce mascherato via wlp3s0
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o wlp3s0 -j MASQUERADE

# Permettere forwarding da enp2s0 a wlp3s0 e ritorno
sudo iptables -A FORWARD -i enp2s0 -o wlp3s0 -j ACCEPT
sudo iptables -A FORWARD -i wlp3s0 -o enp2s0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Verificare
sudo iptables -t nat -L POSTROUTING -n -v
sudo iptables -L FORWARD -n -v
```

**Persistenza** (sopravvive ai reboot):

```bash
sudo apt install iptables-persistent   # se non già installato
sudo netfilter-persistent save
```

## Step 3 — Verificare internet su Gaia-Windows

```powershell
# Da Gaia-Windows
ping 8.8.8.8          # test IP (bypassa DNS)
ping google.com       # test DNS
curl https://ifconfig.me  # verifica IP pubblico (deve mostrare l'IP di SOL)
```

## Step 4 — OpenSSH Server su Windows

PowerShell come Amministratore:

```powershell
# Installare OpenSSH Server (built-in Windows 10/11)
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Avviare e abilitare al boot
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Firewall
New-NetFirewallRule -Name "OpenSSH-Server" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

## Step 5 — Configurare SSH su SOL

Aggiungere a `~/.ssh/config`:

```
Host gaia-win
    HostName 10.0.0.2
    User massimiliano
    IdentityFile ~/.ssh/id_ed25519
```

Copiare la chiave pubblica:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub massimiliano@10.0.0.2
```

**Nota Windows Admin**: se l'utente è nel gruppo Administrators, la authorized_keys va in `C:\ProgramData\ssh\administrators_authorized_keys`:

```powershell
# Su Gaia-Windows
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "SYSTEM:F" /grant "Administrators:F"
```

## Verifica end-to-end

1. Da Gaia-Windows: `ping 10.0.0.1` → raggiunge SOL
2. Da Gaia-Windows: `ping 8.8.8.8` → internet via SOL
3. Da Gaia-Windows: `ping google.com` → DNS funziona
4. Da SOL: `ssh gaia-win hostname` → SSH funziona

## File da modificare su SOL

- `~/.ssh/config` — aggiungere entry `gaia-win`
- `iptables` — regole NAT masquerade (persistite con netfilter-persistent)

## Note

- Le regole iptables NAT servono anche quando Gaia boota su Linux (stessa subnet 10.0.0.x)
- Se SOL ha già regole FORWARD restrittive (policy DROP), le regole ACCEPT sopra sono necessarie
- Se la policy FORWARD è ACCEPT, bastano la regola MASQUERADE
