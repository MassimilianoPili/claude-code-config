---
name: dss-framework
description: "EU DSS 5.12.1 framework reference: signature formats, validation, trusted lists, constraint policy, algorithms, and project integration architecture for PADigitale."
category: backend
tags: [dss, digital-signature, eidas, pades, cades, trusted-list]
version: 1.0.0
allowed-tools: [Read, Write, Edit, Bash]
---

# EU DSS Framework - Riferimento Completo

Riferimento tecnico completo per il framework EU Digital Signature Service (DSS) v5.12.1 come usato nel progetto PADigitale.

## Overview

- **Framework**: EU Digital Signature Service (DSS)
- **Versione**: 5.12.1 (`${dss.version}` in `pom.xml`)
- **Licenza**: LGPL 2.1
- **Sviluppatore**: Nowina Solutions per la Commissione Europea (Digital Europe Programme)
- **Maven GroupId**: `eu.europa.ec.joinup.sd-dss`
- **Repository Maven**: https://ec.europa.eu/cefdigital/artifact/content/repositories/esignaturedss/
- **GitHub**: https://github.com/esig/dss
- **Documentazione**: https://ec.europa.eu/digital-building-blocks/DSS/webapp-demo/doc/dss-documentation.html
- **Java**: 11 (progetto), 8+ (requisito minimo DSS)
- **Regolamento**: eIDAS (EU 910/2014)

## Quando Usare Questa Skill

Usa `/dss` quando:
- Lavori su verifica firme digitali nel progetto PADigitale
- Devi capire classi, enum o configurazioni DSS
- Devi interpretare risultati di validazione (Indications, SubIndications)
- Devi modificare constraint.xml o dssconfig.properties
- Devi aggiungere supporto per nuovi formati firma o livelli
- Devi debuggare problemi con Trusted List o revoca certificati

---

## Formati Firma

### SignatureForm

| Form | Standard | Estensione | Usato nel Progetto |
|------|----------|------------|-------------------|
| **CAdES** | ETSI EN 319 122 | `.p7m` | Si |
| **PAdES** | ETSI EN 319 142 | `.pdf` (firma embedded) | Si |
| **PKCS7** | ISO 32000 | `.pdf` (firma non-ETSI) | Si (PKCS7_B) |
| **XAdES** | ETSI EN 319 132 | `.xml` | No (modulo non incluso) |
| **JAdES** | ETSI TS 119 182 | `.json` (JWS extension) | No (modulo non incluso) |
| **ASiC** | ETSI EN 319 162 | `.asice`, `.asics` | Si (dss-asic-cades) |

### SignaturePackaging

| Packaging | Descrizione |
|-----------|-------------|
| **ENVELOPED** | Firma contenuta nel documento firmato (PAdES usa sempre questo) |
| **ENVELOPING** | Firma avvolge il documento firmato (CAdES `.p7m`) |
| **DETACHED** | Firma separata dal documento |
| **INTERNALLY_DETACHED** | Firma con documento incluso (solo XAdES) |

### Livelli Firma Usati nel Progetto

Da `VerificaDocumentiUtils.java`:

**CAdES** (se `abilitaVerificaCades=true`):

| Livello | Tipo |
|---------|------|
| `CAdES_BASELINE_B` | Baseline Basic |
| `CAdES_BASELINE_T` | Baseline con Timestamp |
| `CAdES_BASELINE_LT` | Baseline Long-Term |
| `CAdES_BASELINE_LTA` | Baseline Long-Term Archival |
| `CAdES_A` | Archival (legacy) |
| `CAdES_C` | Complete (legacy) |
| `CAdES_X` | Extended (legacy) |
| `CAdES_XL` | Extended Long-Term (legacy) |

**PAdES** (se `abilitaVerificaEOFPAdes=true`):

| Livello | Tipo |
|---------|------|
| `PAdES_BASELINE_B` | Baseline Basic |
| `PAdES_BASELINE_T` | Baseline con Timestamp |
| `PAdES_BASELINE_LT` | Baseline Long-Term |
| `PAdES_BASELINE_LTA` | Baseline Long-Term Archival |
| `PKCS7_B` | PDF PKCS#7 Basic (ISO 32000, non-ETSI) |

### Livelli Baseline - Descrizione Dettagliata

| Livello | Nome Completo | Cosa Aggiunge |
|---------|---------------|---------------|
| **B** | Basic | Valore firma crittografico, riferimento certificato firmatario, data firma, attributi opzionali. Firma minima valida. |
| **T** | Timestamp | Aggiunge un timestamp trusted (RFC 3161) che prova l'esistenza della firma a un certo momento. Non-repudiation evidence. |
| **LT** | Long-Term | Incorpora tutto il materiale di validazione (catena certificati, risposte CRL/OCSP) nella firma. Permette validazione offline anche se l'infrastruttura CA diventa indisponibile. |
| **LTA** | Long-Term Archival | Aggiunge timestamp archivio periodici sull'intera firma + dati validazione. Protegge contro obsolescenza algoritmi tramite re-timestamping con algoritmi piu' forti. |

---

## Framework di Validazione

### Indicazioni Principali

| Indication | Descrizione |
|------------|-------------|
| **TOTAL_PASSED** | Tutti i controlli crittografici e vincoli policy superati |
| **TOTAL_FAILED** | Controllo crittografico fallito o certificato invalido al momento della firma |
| **INDETERMINATE** | Non e' possibile determinare PASSED o FAILED (es. dati revoca mancanti) |
| **NO_SIGNATURE_FOUND** | Nessuna firma trovata nel documento (estensione DSS, non ETSI) |

### SubIndications

Vedi [references/dss-validation-enums.md](references/dss-validation-enums.md) per la tabella completa dei 25 valori.

Piu' comuni nel progetto:
- `FORMAT_FAILURE` - Firma non conforme al formato base
- `HASH_FAILURE` - Hash mismatch tra dati firmati e firma
- `SIG_CRYPTO_FAILURE` - Valore firma non verificabile con chiave pubblica firmatario
- `REVOKED` - Certificato revocato prima della creazione firma
- `EXPIRED` - Firma creata dopo scadenza certificato
- `NO_SIGNING_CERTIFICATE_FOUND` - Certificato firmatario non identificabile
- `NO_CERTIFICATE_CHAIN_FOUND` - Catena certificati non trovata
- `CRYPTO_CONSTRAINTS_FAILURE` - Algoritmo/chiave sotto livello sicurezza richiesto

### Qualificazione Firma

| Qualificazione | Descrizione |
|----------------|-------------|
| **QESIG** | Firma Elettronica Qualificata (livello massimo) |
| **QESEAL** | Sigillo Elettronico Qualificato |
| **ADESIG_QC** | Firma Elettronica Avanzata + Certificato Qualificato |
| **ADESEAL_QC** | Sigillo Elettronico Avanzato + Certificato Qualificato |
| **ADESIG** | Firma Elettronica Avanzata |
| **ADESEAL** | Sigillo Elettronico Avanzato |
| **NOT_ADES** | Non conforme AdES |
| **NA** | Non applicabile |

Vedi [references/dss-validation-enums.md](references/dss-validation-enums.md) per tutti i 22 valori di qualificazione firma e 12 valori di qualificazione certificato.

---

## Gestione Trusted List

### Architettura LOTL/TL

L'infrastruttura di trust EU usa un modello gerarchico:

- **LOTL (List of Trusted Lists)**: pubblicata dalla Commissione Europea, contiene link a tutte le Trusted List degli Stati Membri
  - URL: `https://ec.europa.eu/tools/lotl/eu-lotl.xml`
  - Formato: ETSI TS 119 612
- **TL (Trusted List)**: ogni Stato Membro pubblica la propria TL con i trust service provider qualificati e i loro certificati

### Classi DSS per Gestione TL

| Classe | Package | Uso nel Progetto |
|--------|---------|------------------|
| `TLValidationJob` | `eu.europa.esig.dss.tsl.job` | Orchestratore principale: download, parsing, validazione TL/LOTL |
| `LOTLSource` | `eu.europa.esig.dss.tsl.source` | Configurazione endpoint LOTL (URL, predicate, certificati) |
| `TrustedListsCertificateSource` | `eu.europa.esig.dss.spi.tsl` | Sorgente certificati popolata dalle Trusted Lists |
| `FileCacheDataLoader` | `eu.europa.esig.dss.service.http.commons` | Cache file-system per risorse scaricate |
| `CommonsDataLoader` | `eu.europa.esig.dss.service.http.commons` | HTTP data loader (Apache HttpClient) |
| `IgnoreDataLoader` | `eu.europa.esig.dss.spi.client.http` | Loader no-op per modalita' offline |
| `CacheCleaner` | `eu.europa.esig.dss.tsl.cache` | Pulizia cache stale |
| `AcceptAllStrategy` | `eu.europa.esig.dss.tsl.sync` | Strategia sync che accetta tutte le entry TL |
| `TLPredicateFactory` | `eu.europa.esig.dss.tsl.function` | Filtro TL per codice paese |

### Sistema Alert TL

| Detection | Handler | Scopo |
|-----------|---------|-------|
| `TLSignatureErrorDetection` | `LogTLSignatureErrorAlertHandler` | Firma TL non valida |
| `TLExpirationDetection` | `LogTLExpirationAlertHandler` | TL scaduta |
| `OJUrlChangeDetection` | `LogOJUrlChangeAlertHandler` | URL Gazzetta Ufficiale cambiato |
| `LOTLLocationChangeDetection` | `LogLOTLLocationChangeAlertHandler` | URL LOTL cambiato |

### Data Loaders

- **Online**: `FileCacheDataLoader` + `CommonsDataLoader` (fallback HTTP), cache expiration = 0 (sempre aggiorna)
- **Offline**: `FileCacheDataLoader` + `IgnoreDataLoader` (nessun download), cache expiration = MAX_VALUE

### Paesi Supportati (30)

Da `CaricaTrustedList.java`:

```text
AT, BE, BG, CY, CZ, DE, DK, EE, EL, ES, FI, FR, HR, HU, IE,
IS, IT, LI, LT, LU, LV, MT, NL, NO, PL, PT, RO, SE, SI, SK
```

27 EU + 3 EEA (IS=Islanda, LI=Liechtenstein, NO=Norvegia). UK escluso.

---

## Verifica Certificati e Revoca

### CommonCertificateVerifier

Classe centrale per configurare le sorgenti di verifica certificati.

**Due modalita' nel progetto:**

**A. Senza Trusted List** (`DssUtilities.setUpDefaultCertificateVerifier()`):
```java
CommonCertificateVerifier verifier = new CommonCertificateVerifier();
verifier.setAIASource(new DefaultAIASource());
verifier.setOcspSource(new OnlineOCSPSource());
verifier.setCrlSource(new OnlineCRLSource());
```

**B. Con Trusted List** (da `CaricaTrustedList`):
```java
CommonCertificateVerifier verifier = new CommonCertificateVerifier();
verifier.setTrustedCertSources(trustedListsCertificateSource);
verifier.setCrlSource(onlineCRLSourceWithCache);
verifier.setOcspSource(new OnlineOCSPSource());
verifier.setAIASource(new DefaultAIASource());
```

### Sorgenti Revoca

| Sorgente | Classe DSS | Scopo |
|----------|-----------|-------|
| **CRL** | `OnlineCRLSource` | Scarica Certificate Revocation Lists dai distribution point |
| **OCSP** | `OnlineOCSPSource` | Query OCSP responder per stato revoca in tempo reale |
| **AIA** | `DefaultAIASource` | Scarica certificati CA intermedi dall'estensione Authority Information Access |

### Configurazione (da dssconfig.properties)

| Proprieta' | Default | Descrizione |
|------------|---------|-------------|
| `OnlineCRLSource_enabled` | `Y` | Abilita controllo CRL |
| `OnlineOCSPSource_enabled` | `Y` | Abilita controllo OCSP |
| `DefaultAIASource_enabled` | `Y` | Abilita fetch certificati AIA |
| `COMMON_DATA_LOADER_TimeoutConnection` | (nessuno) | Timeout connessione HTTP (ms) |
| `COMMON_DATA_LOADER_TimeoutSocket` | (nessuno) | Timeout socket HTTP (ms) |
| `COMMON_DATA_LOADER_CacheExpirationTime` | `36000000000000` | TTL cache CRL (ms, ~1141 anni = praticamente permanente) |

---

## Tipi Timestamp

| Tipo | Copre Firma? | Descrizione |
|------|-------------|-------------|
| `CONTENT_TIMESTAMP` | No | Timestamp sul contenuto prima della firma |
| `ALL_DATA_OBJECTS_TIMESTAMP` | No | Tutti gli oggetti dati (XAdES) |
| `INDIVIDUAL_DATA_OBJECTS_TIMESTAMP` | No | Oggetti dati individuali (XAdES) |
| `SIGNATURE_TIMESTAMP` | Si | Timestamp sulla firma (livello T) |
| `VRI_TIMESTAMP` | Si | Timestamp VRI (PAdES /VRI/TS) |
| `VALIDATION_DATA_REFSONLY_TIMESTAMP` | No | Riferimenti dati validazione |
| `VALIDATION_DATA_TIMESTAMP` | Si | Firma + riferimenti dati validazione |
| `CONTAINER_TIMESTAMP` | Si | Timestamp detached container (ASiC) |
| `DOCUMENT_TIMESTAMP` | Si | Timestamp documento (PAdES-LTV) |
| `ARCHIVE_TIMESTAMP` | Si | Timestamp archivio (livello LTA) |
| `EVIDENCE_RECORD_TIMESTAMP` | Si | Timestamp evidence record |

---

## Classi DSS Principali

### Validazione Documenti

| Classe | Uso |
|--------|-----|
| `SignedDocumentValidator` | Entry point principale. `fromDocument(DSSDocument)` auto-rileva formato (CAdES/PAdES/ASiC) |
| `Reports` | Container per tutti i report validazione: `getSimpleReport()`, `getDetailedReport()`, `getDiagnosticData()` |
| `SimpleReport` | Riepilogo: `getSignatureIdList()`, `getValidSignaturesCount()`, `getIndication()`, `getSubIndication()`, `getSignatureFormat()` |
| `SimpleReportFacade` | `newFacade().generateHtmlReport(xmlSimpleReport)` genera report HTML Bootstrap |
| `DiagnosticData` | Dati diagnostici: `getSignatureIdList()`, `getJaxbModel()` |
| `DiagnosticDataFacade` | `newFacade().marshall(xmlDiagnosticData)` serializza a XML |

### Modello Documenti

| Classe | Uso |
|--------|-----|
| `DSSDocument` | Interfaccia base: `openStream()`, `getDigest()`, `getName()`, `getMimeType()` |
| `InMemoryDocument` | Documento in memoria: `new InMemoryDocument(byte[])` - usato per i documenti dal frontend |
| `FileDocument` | Documento da file |

### Modello JAXB Diagnostico

| Classe | Uso nel Progetto |
|--------|------------------|
| `XmlDiagnosticData` | `getSignatures()` per iterare sulle firme |
| `XmlSignature` | `getCertificateChain()` per la catena certificati |
| `XmlChainItem` | `getCertificate().getSubjectSerialNumber()` per estrazione codice fiscale |

---

## Architettura Integrazione Progetto

### Gerarchia Classi

```text
VerificaDocumenti (interfaccia pubblica)
  └── VerificaDocumentiImpl (singleton)
        └── VerificaDocumentiUtils (logica core)
              ├── DssUtilities (motore validazione DSS)
              │     └── SignedDocumentValidator.fromDocument()
              ├── CaricaTrustedList (gestione TL)
              │     └── TLValidationJob
              ├── OnlineSourceHelper (config CRL/OCSP/AIA)
              │     └── OnlineCRLSourceHelper (cache CRL)
              └── DssReportUtilities (report HTML/SimpleReport)
```

### Flusso Verifica Completo (`verificaDocumenti()`)

1. **Validazione request**: null check su request, documenti, codice fiscale
2. **Conversione documento**: `byte[]` → `InMemoryDocument`
3. **Verifica firma TL**: `verificaFirmaTrusted()` con `CommonCertificateVerifier` + TL
4. **Check tipo firma**: `verificaFirmaCadesOrPades()` - deve essere CAdES o PAdES
5. **Estrazione originale**: `extractOriginalDocuments()` dal documento firmato
6. **Confronto MD5**: hash originale vs estratto (con fallback PAdES EOF se abilitato)
7. **Confronto firmatario**: codice fiscale dalla catena certificati (`SubjectSerialNumber`, prefisso `TINIT-` o `IT:`)

### Codici Risposta

**Esito:**

| Esito | Descrizione |
|-------|-------------|
| `OK` | Verifica superata |
| `KO` | Verifica fallita |
| `ERROR` | Input invalido o eccezione |

**Messaggio (13 codici):**

| Codice | Quando |
|--------|--------|
| `ERR_REQUEST_NULL` | Request e' null |
| `ERR_DOC_VUOTO` | Documento null o vuoto |
| `ERR_DOC_ORIGINALE_VUOTO` | Documento originale null o vuoto |
| `ERR_CF_INPUT_NULL` | Codice fiscale input null/vuoto |
| `ERR_CF_DOC_NULL` | Codice fiscale non trovato nel documento firmato |
| `KO_DOC_NOSIGN` | Nessuna firma trovata |
| `KO_DOC_NOVALIDSIGN` | Nessuna firma valida |
| `KO_DOC_NOT_EQUAL` | Hash MD5 diversi (documenti non uguali) |
| `KO_DOC_NOT_CADES_OR_PADES` | Formato firma non supportato |
| `KO_DOC_NOT_EQUAL_FIRMATARIO` | Codice fiscale non corrisponde |
| `KO_DOC_MORESIGN` | Firme multiple (riservato) |
| `KO_GET_ORIG_DOC` | Impossibile estrarre documento originale |
| `KO_TL_LOAD_OFFLINE` | TL caricata da cache offline (non online) |
| `KO_TL_NOT_LOAD` | TL non caricata (ne' online ne' offline) |

### Gestione Speciale PAdES EOF

Se `abilitaVerificaEOFPAdes=true` e la firma e' PAdES:
1. Legge lo stream di byte del PDF
2. Cerca il marker `%%EOF`
3. Ricostruisce il documento fino a `%%EOF`
4. Ritenta il confronto MD5 con il documento "pulito"

Scopo: gestire PAdES malformati con contenuto extra dopo `%%EOF`.

---

## Riferimento Configurazione

### dssconfig.properties

| Proprieta' | Valore Default | Descrizione |
|------------|---------------|-------------|
| `loltUrl` | `https://ec.europa.eu/tools/lotl/eu-lotl.xml` | URL download LOTL EU |
| `folder` | `DSS/https___ec_europa_eu_LOTL_EU_LOTL_xml` | Path SFTP per LOTL offline |
| `urlCache` | `DSS/CACHE` | Directory cache TL locale |
| `abilitaVerificaEOFPAdes` | `true` | Abilita gestione EOF per PAdES |
| `abilitaVerificaCades` | `true` | Abilita verifica firme CAdES |
| `OnlineCRLSource_enabled` | `Y` | Abilita controllo CRL online |
| `OnlineOCSPSource_enabled` | `Y` | Abilita controllo OCSP online |
| `DefaultAIASource_enabled` | `Y` | Abilita fetch certificati AIA |
| `COMMON_DATA_LOADER_CacheExpirationTime` | `36000000000000` | TTL cache CRL (ms) |

### constraint.xml

Policy di validazione: **"QES AdESQC TL based"** - valida firme come AdES/QC o QES contro le Trusted List degli Stati Membri EU.

Vedi [references/dss-constraint-policy.md](references/dss-constraint-policy.md) per la struttura completa.

**Impostazioni chiave:**
- Modello validazione: **SHELL** (ogni certificato validato al proprio tempo d'uso)
- Algoritmi accettati: RSA, DSA, ECDSA, PLAIN-ECDSA
- Digest accettati: SHA256+ (SHA1/MD5 scaduti)
- eIDAS: TL freshness 6h (WARN), TL version 5 (FAIL)
- Livello constraint: FAIL blocca validazione, WARN avviso nel report

**File varianti:**
- `constraint.xml` - attuale con date algoritmo estese
- `constraint_original.xml` - default framework DSS
- `constraint_prod_fino_al_08_01_2026.xml` - produzione fino al 08/01/2026

---

## Standard di Conformita'

| Standard | Titolo | Rilevanza |
|----------|--------|-----------|
| **eIDAS 910/2014/EU** | Identificazione Elettronica e Servizi Fiduciari | Framework legale |
| **ETSI EN 319 102-1** | Procedure creazione e validazione firma | Indications, SubIndications |
| **ETSI TS 119 102-2** | Formato report validazione firma | Report XML/HTML |
| **ETSI EN 319 122** | CAdES | Firme CMS avanzate (.p7m) |
| **ETSI EN 319 142** | PAdES | Firme PDF avanzate |
| **ETSI EN 319 162** | ASiC | Container firme associate |
| **ETSI TS 119 612** | Trusted Lists | Formato e gestione TL |
| **ETSI TS 119 615** | Uso e interpretazione Trusted Lists | Regole trust |
| **ETSI 119 312** | Cryptographic Suites | Date scadenza algoritmi |
| **ETSI TS 102 176-1** | Algoritmi e Parametri (storico) | Date scadenza legacy |
| **RFC 3161** | Time-Stamp Protocol | Timestamp trusted |
| **RFC 5280** | X.509 PKI | Validazione catena certificati |
| **RFC 5652** | Cryptographic Message Syntax | CMS/PKCS#7 |
| **RFC 6960** | OCSP | Stato revoca certificati |
| **ISO 32000-1/2** | PDF | Formato documenti PDF |
| **Decisione 2015/1506/EU** | Riconoscimento formati firma | Formati accettati EU |

---

## Riferimenti Dettagliati

Per informazioni approfondite consulta i file nella directory `references/`:

- [dss-modules.md](references/dss-modules.md) - 31 moduli DSS con artifact e scopo
- [dss-validation-enums.md](references/dss-validation-enums.md) - SubIndications (25), Qualificazione firma (22), Qualificazione certificato (12)
- [dss-constraint-policy.md](references/dss-constraint-policy.md) - Struttura completa constraint.xml con tutti i vincoli
- [dss-crypto-algorithms.md](references/dss-crypto-algorithms.md) - Algoritmi digest (16) e cifratura (9) con OID e date scadenza ETSI
