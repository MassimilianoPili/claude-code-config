# Validation Policy (constraint.xml) - Riferimento Completo

Policy: **"QES AdESQC TL based"** - valida firme elettroniche come AdES/QC o QES contro Trusted List EU.

File: `dss-wrapper/verifica-documenti-dss/src/main/resources/constraint.xml`

## Livelli Constraint

| Livello | Effetto |
|---------|---------|
| **FAIL** | Validazione fallisce se vincolo non soddisfatto |
| **WARN** | Warning nel report ma validazione continua |
| **INFORM** | Solo informativo, nessun impatto sul risultato |
| **IGNORE** | Vincolo non controllato |

## Struttura Policy

### 1. ContainerConstraints (ASiC)

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `AcceptableContainerTypes` | FAIL | Tipi accettati: ASiC-S, ASiC-E |
| `MimeTypeFilePresent` | FAIL | File mimetype presente nel container |
| `AcceptableMimeTypeFileContent` | WARN | Contenuto mimetype accettabile |
| `ManifestFilePresent` | FAIL | Manifest presente |
| `SignedFilesPresent` | FAIL | File firmati presenti |
| `AllFilesSigned` | WARN | Tutti i file nel container firmati |

### 2. SignatureConstraints

**Vincoli Strutturali:**

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `StructuralValidation` | WARN | Validazione strutturale firma |
| `AcceptablePolicies` | FAIL | Policy accettate: ANY_POLICY, NO_POLICY |
| `AcceptableFormats` | FAIL | Formati accettati: `*` (tutti) |

**BasicSignatureConstraints:**

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `ReferenceDataExistence` | FAIL | Dati di riferimento esistono |
| `ReferenceDataIntact` | FAIL | Dati di riferimento integri |
| `SignatureIntact` | FAIL | Firma crittograficamente integra |
| `SignatureDuplicated` | FAIL | Firma non duplicata |
| `ProspectiveCertificateChain` | FAIL | Catena certificati prospettica valida |
| `SignerInformationStore` | FAIL | Informazioni firmatario presenti |
| `PdfPageDifference` | FAIL | Differenze pagine PDF |
| `PdfAnnotationOverlap` | WARN | Sovrapposizione annotazioni PDF |
| `PdfVisualDifference` | WARN | Differenze visuali PDF |
| `DocMDP` | WARN | Modifica documento PDF (MDP) |
| `FieldMDP` | WARN | Modifica campo PDF |
| `SigFieldLock` | WARN | Lock campo firma |
| `UndefinedChanges` | WARN | Modifiche non definite |

**Vincoli Certificato Firmatario:**

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `Recognition` | FAIL | Certificato riconosciuto |
| `Signature` | FAIL | Firma certificato valida |
| `NotExpired` | FAIL | Certificato non scaduto |
| `AuthorityInfoAccessPresent` | WARN | AIA presente |
| `RevocationInfoAccessPresent` | WARN | Info accesso revoca presente |
| `RevocationDataAvailable` | FAIL | Dati revoca disponibili |
| `AcceptableRevocationDataFound` | FAIL | Dati revoca accettabili trovati |
| `CRLNextUpdatePresent` | WARN | CRL NextUpdate presente |
| `RevocationFreshness` | IGNORE | Freschezza revoca (0 giorni) |
| `KeyUsage` | WARN | Key usage: `nonRepudiation` |
| `SerialNumberPresent` | INFORM | Numero seriale presente |
| `NotRevoked` | FAIL | Non revocato |
| `NotOnHold` | FAIL | Non sospeso |
| `RevocationIssuerNotExpired` | FAIL | Emittente revoca non scaduto |
| `NotSelfSigned` | WARN | Non auto-firmato |
| `UsePseudonym` | INFORM | Uso pseudonimo |

**Vincoli Certificato CA:**

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `Signature` | FAIL | Firma CA valida |
| `NotExpired` | FAIL | CA non scaduta |
| `RevocationDataAvailable` | FAIL | Dati revoca CA disponibili |
| `AcceptableRevocationDataFound` | FAIL | Dati revoca CA accettabili |
| `CRLNextUpdatePresent` | WARN | CRL NextUpdate CA presente |
| `NotRevoked` | FAIL | CA non revocata |
| `NotOnHold` | FAIL | CA non sospesa |

**SignedAttributes:**

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `SigningCertificatePresent` | WARN | Certificato firma presente negli attributi |
| `UnicitySigningCertificate` | WARN | Unicita' certificato firma |
| `CertDigestPresent` | FAIL | Digest certificato presente |
| `CertDigestMatch` | FAIL | Digest certificato corrisponde |
| `SigningTime` | FAIL | Data firma presente |
| `MessageDigestOrSignedPropertiesPresent` | FAIL | Message digest o signed properties presente |

### 3. Timestamp

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `TimestampDelay` | IGNORE | Ritardo timestamp (0 giorni) |
| `RevocationTimeAgainstBestSignatureTime` | FAIL | Tempo revoca vs migliore tempo firma |
| `BestSignatureTimeBeforeExpirationDateOfSigningCertificate` | FAIL | Migliore tempo firma prima scadenza certificato |
| `Coherence` | WARN | Coerenza timestamp |
| `MessageImprintDataFound` | FAIL | Dati impronta messaggio trovati |
| `MessageImprintDataIntact` | FAIL | Dati impronta messaggio integri |
| TSA `ExtendedKeyUsage` | WARN | `timeStamping` |

### 4. Revocation

| Vincolo | Livello | Descrizione |
|---------|---------|-------------|
| `UnknownStatus` | FAIL | Stato revoca sconosciuto |
| `OCSPCertHashPresent` | WARN | Hash certificato OCSP presente |
| `OCSPCertHashMatch` | FAIL | Hash certificato OCSP corrisponde |
| `SelfIssuedOCSP` | WARN | OCSP auto-emesso |

### 5. eIDAS

| Vincolo | Livello | Valore | Descrizione |
|---------|---------|--------|-------------|
| `TLFreshness` | WARN | 6 ore (21600000 ms) | Freschezza Trusted List |
| `TLNotExpired` | WARN | - | TL non scaduta |
| `TLWellSigned` | WARN | - | TL ben firmata |
| `TLVersion` | FAIL | 5 | Versione TL |

### 6. Modello di Validazione

| Modello | Descrizione |
|---------|-------------|
| **SHELL** (attivo) | Ogni certificato nella catena validato al proprio tempo d'uso. La validazione si ferma quando trova un trust anchor. |
| CHAIN | Tutti i certificati validati al tempo di firma dichiarato |
| HYBRID | Approccio combinato |

## File Varianti

| File | Descrizione |
|------|-------------|
| `constraint.xml` | **Attuale** - date algoritmo estese (SHA256→2029, RSA 1024→2027) |
| `constraint_original.xml` | Default framework DSS |
| `constraint_prod_fino_al_08_01_2026.xml` | Produzione fino al 08/01/2026 con date ETSI originali |

### Differenze Chiave tra Varianti

La differenza principale e' nelle date di scadenza algoritmi nella sezione `<Cryptographic>`:

| Algoritmo | constraint.xml (attuale) | constraint_prod (ETSI originali) |
|-----------|-------------------------|----------------------------------|
| SHA256 | 2029 | 2026 |
| RSA 1024-bit | 2027 | 2013 |
| RSA 1536-bit | 2027 | 2013 |
| RSA 1900-bit | 2027 | 2026 |
