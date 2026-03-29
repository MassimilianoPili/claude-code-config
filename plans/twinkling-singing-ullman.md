# Plan: Riscrittura PIANO_CARTE_SPESA.md — iOS Nativo + Apple Wallet

## Context

Il piano originale era KMP cross-platform. La ricerca ha rivelato che:
- Catima copre Android egregiamente — il gap e' iOS (zero app open-source native di qualita')
- Apple Wallet non supporta EAN-13 — serve workaround strip image + server per firma PKPass
- L'utente vuole qualita' design Obsidian/Notion e integrazione profonda ecosistema Apple

Decisioni utente:
- iOS nativo SwiftUI (non KMP)
- Server SOL (Go) per firma PKPass
- iCloud sync (SwiftData + CloudKit) in V1
- Import Catima per migrazione da Android
- Feature extra: condivisione familiare, OCR nome/logo, statistiche utilizzo

## Steps

1. **Sostituire** `/data/massimiliano/progetti_futuri/PIANO_CARTE_SPESA.md` con piano riscritto
   che copre tutti i seguenti aspetti:

   **Architettura:**
   - SwiftUI, SwiftData + CloudKit, iOS 17+ (iOS 18+ per MeshGradient/zoom)
   - VisionKit DataScannerViewController (scanning)
   - CIFilter + Core Graphics (barcode rendering)
   - Vision VNRecognizeTextRequest (OCR nome carta)
   - UIImageColors (color extraction)
   - Swift Charts (statistiche utilizzo)
   - PKPass/PassKit (Apple Wallet)

   **Server SOL (`pkpass-signer`):**
   - Go micro-service, scratch image, ~64m, rete shared
   - POST /sign — JSON carta → .pkpass firmato
   - Auth: JWT via jwt-gateway
   - Nginx: /wallet/ strip prefix (porte 80 + 8888)
   - Certificato .p12 in volume Docker

   **Feature set V1:**
   - 14 MUST (scan, manual, CRUD, Apple Wallet, fullscreen, grid, search, sort,
     favorites, groups, iCloud sync, backup, Catima import, dark theme)
   - 5 SHOULD (widgets, OCR nome/logo, color extraction, duplicati, statistiche)
   - 4 COULD (Live Activities, Siri Shortcuts, family sharing, Stocard import)

   **Design premium:**
   - MeshGradient, zoom NavigationTransition, spring animations
   - .sensoryFeedback(), SF Pro Dynamic Type, semantic colors

   **Milestones:** ~15 giorni (12 app iOS + 3 server SOL + infra)

## File da modificare

- `/data/massimiliano/progetti_futuri/PIANO_CARTE_SPESA.md` — sostituzione completa

## Verification

- Leggere il file dopo scrittura per verificare formattazione
- Coerenza stile con altri PIANO_*.md
