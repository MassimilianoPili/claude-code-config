# Enum di Validazione DSS - Riferimento Completo

## SubIndications (25 valori)

Da ETSI EN 319 102-1, enum `SubIndication` in `dss-enumerations`.

| SubIndication | Descrizione |
|---------------|-------------|
| `FORMAT_FAILURE` | Firma non conforme agli standard formato base |
| `HASH_FAILURE` | Mismatch hash tra dati firmati e firma |
| `SIG_CRYPTO_FAILURE` | Valore firma non verificabile con chiave pubblica firmatario |
| `REVOKED` | Certificato revocato prima della creazione firma |
| `EXPIRED` | Firma creata dopo scadenza certificato |
| `NOT_YET_VALID` | Firma creata prima dell'emissione certificato |
| `SIG_CONSTRAINTS_FAILURE` | Attributi firma non superano vincoli policy |
| `CHAIN_CONSTRAINTS_FAILURE` | Catena certificati non supera vincoli policy |
| `CERTIFICATE_CHAIN_GENERAL_FAILURE` | Errore generale catena certificati |
| `CRYPTO_CONSTRAINTS_FAILURE` | Algoritmo/chiave sotto livello sicurezza richiesto |
| `POLICY_PROCESSING_ERROR` | File policy formale non elaborabile |
| `SIGNATURE_POLICY_NOT_AVAILABLE` | Documento policy referenziato non disponibile |
| `TIMESTAMP_ORDER_FAILURE` | Ordinamento timestamp violato |
| `NO_SIGNING_CERTIFICATE_FOUND` | Certificato firmatario non identificabile |
| `NO_CERTIFICATE_CHAIN_FOUND` | Catena certificati non localizzata |
| `NO_CERTIFICATE_CHAIN_FOUND_NO_POE` | Catena non trovata + nessuna prova di esistenza |
| `REVOKED_NO_POE` | Certificato revocato ma data firma incerta |
| `REVOKED_CA_NO_POE` | Certificato CA intermedio revocato |
| `OUT_OF_BOUNDS_NOT_REVOKED` | Certificato scaduto ma non revocato |
| `OUT_OF_BOUNDS_NO_POE` | Certificato scaduto + data firma incerta |
| `REVOCATION_OUT_OF_BOUNDS_NO_POE` | Validita' certificato info revoca incerta |
| `CRYPTO_CONSTRAINTS_FAILURE_NO_POE` | Algoritmo debole + nessuna prova di produzione anticipata |
| `NO_POE` | Prova di esistenza mancante prima di evento compromissione |
| `TRY_LATER` | Dati revoca aggiuntivi potrebbero risolvere lo stato in futuro |
| `SIGNED_DATA_NOT_FOUND` | Dati firmati non ottenibili |

## Qualificazione Firma (22 valori)

Da enum `SignatureQualification` in `dss-enumerations`.

### Qualificazione Determinata

| Qualificazione | Descrizione |
|----------------|-------------|
| `QESIG` | Firma Elettronica Qualificata (livello massimo eIDAS) |
| `QESEAL` | Sigillo Elettronico Qualificato |
| `UNKNOWN_QC_QSCD` | Certificato Qualificato, tipo sconosciuto, chiave privata su QSCD |
| `ADESIG_QC` | Firma Elettronica Avanzata + Certificato Qualificato |
| `ADESEAL_QC` | Sigillo Elettronico Avanzato + Certificato Qualificato |
| `UNKNOWN_QC` | Certificato Qualificato, tipo sconosciuto |
| `ADESIG` | Firma Elettronica Avanzata |
| `ADESEAL` | Sigillo Elettronico Avanzato |
| `UNKNOWN` | Tipo sconosciuto |

### Qualificazione Indeterminata

| Qualificazione | Descrizione |
|----------------|-------------|
| `INDETERMINATE_QESIG` | QES indeterminato |
| `INDETERMINATE_QESEAL` | QESeal indeterminato |
| `INDETERMINATE_UNKNOWN_QC_QSCD` | QC + QSCD indeterminato |
| `INDETERMINATE_ADESIG_QC` | AdESig + QC indeterminato |
| `INDETERMINATE_ADESEAL_QC` | AdESeal + QC indeterminato |
| `INDETERMINATE_UNKNOWN_QC` | QC indeterminato |
| `INDETERMINATE_ADESIG` | AdESig indeterminato |
| `INDETERMINATE_ADESEAL` | AdESeal indeterminato |
| `INDETERMINATE_UNKNOWN` | Sconosciuto indeterminato |

### Non AdES

| Qualificazione | Descrizione |
|----------------|-------------|
| `NOT_ADES_QC_QSCD` | Non AdES ma QC + QSCD |
| `NOT_ADES_QC` | Non AdES ma QC |
| `NOT_ADES` | Non AdES |
| `NA` | Non applicabile |

## Qualificazione Certificato (12 valori)

Da enum `CertificateQualification` in `dss-enumerations`.

| Qualificazione | Descrizione |
|----------------|-------------|
| `QCERT_FOR_ESIG_QSCD` | Certificato Qualificato per Firme Elettroniche + QSCD |
| `QCERT_FOR_ESEAL_QSCD` | Certificato Qualificato per Sigilli Elettronici + QSCD |
| `QCERT_FOR_UNKNOWN_QSCD` | Certificato Qualificato tipo sconosciuto + QSCD |
| `QCERT_FOR_ESIG` | Certificato Qualificato per Firme Elettroniche |
| `QCERT_FOR_ESEAL` | Certificato Qualificato per Sigilli Elettronici |
| `QCERT_FOR_WSA` | Certificato Qualificato per Autenticazione Siti Web |
| `QCERT_FOR_UNKNOWN` | Certificato Qualificato tipo sconosciuto |
| `CERT_FOR_ESIG` | Certificato Non-qualificato per Firme Elettroniche |
| `CERT_FOR_ESEAL` | Certificato Non-qualificato per Sigilli Elettronici |
| `CERT_FOR_WSA` | Certificato Non-qualificato per Autenticazione Siti Web |
| `CERT_FOR_UNKNOWN` | Certificato Non-qualificato tipo sconosciuto |
| `NA` | Non applicabile |

## Tutti i SignatureLevel (56 valori)

### XAdES (14 livelli)

| Livello | Tipo |
|---------|------|
| `XML_NOT_ETSI` | Firma XML non conforme ETSI |
| `XAdES_BES` | Basic Electronic Signature (legacy) |
| `XAdES_EPES` | Explicitly Policy-based (legacy) |
| `XAdES_T` | Con timestamp (legacy) |
| `XAdES_LT` | Long-term (legacy) |
| `XAdES_C` | Complete validation data refs (legacy) |
| `XAdES_X` | Extended timestamp (legacy) |
| `XAdES_XL` | Extended long-term (legacy) |
| `XAdES_A` | Archival (legacy) |
| `XAdES_ERS` | Con evidence record |
| `XAdES_BASELINE_B` | Baseline Basic |
| `XAdES_BASELINE_T` | Baseline con Timestamp |
| `XAdES_BASELINE_LT` | Baseline Long-Term |
| `XAdES_BASELINE_LTA` | Baseline Long-Term Archival |

### CAdES (14 livelli)

| Livello | Tipo |
|---------|------|
| `CMS_NOT_ETSI` | Firma CMS non conforme ETSI |
| `CAdES_BES` | Basic Electronic Signature (legacy) |
| `CAdES_EPES` | Explicitly Policy-based (legacy) |
| `CAdES_T` | Con timestamp (legacy) |
| `CAdES_LT` | Long-term (legacy) |
| `CAdES_C` | Complete validation data refs (legacy) |
| `CAdES_X` | Extended timestamp (legacy) |
| `CAdES_XL` | Extended long-term (legacy) |
| `CAdES_A` | Archival (legacy) |
| `CAdES_ERS` | Con evidence record |
| `CAdES_BASELINE_B` | Baseline Basic |
| `CAdES_BASELINE_T` | Baseline con Timestamp |
| `CAdES_BASELINE_LT` | Baseline Long-Term |
| `CAdES_BASELINE_LTA` | Baseline Long-Term Archival |

### PAdES (12 livelli)

| Livello | Tipo |
|---------|------|
| `PDF_NOT_ETSI` | Firma PDF non conforme ETSI |
| `PKCS7_B` | ISO 32000 PKCS#7 Basic |
| `PKCS7_T` | ISO 32000 PKCS#7 con Timestamp |
| `PKCS7_LT` | ISO 32000 PKCS#7 Long-Term |
| `PKCS7_LTA` | ISO 32000 PKCS#7 Long-Term Archival |
| `PAdES_BES` | Basic (legacy) |
| `PAdES_EPES` | Explicitly Policy-based (legacy) |
| `PAdES_LTV` | Long-Term Validation (legacy) |
| `PAdES_BASELINE_B` | Baseline Basic |
| `PAdES_BASELINE_T` | Baseline con Timestamp |
| `PAdES_BASELINE_LT` | Baseline Long-Term |
| `PAdES_BASELINE_LTA` | Baseline Long-Term Archival |

### JAdES (5 livelli)

| Livello | Tipo |
|---------|------|
| `JSON_NOT_ETSI` | Firma JSON non conforme ETSI |
| `JAdES_BASELINE_B` | Baseline Basic |
| `JAdES_BASELINE_T` | Baseline con Timestamp |
| `JAdES_BASELINE_LT` | Baseline Long-Term |
| `JAdES_BASELINE_LTA` | Baseline Long-Term Archival |

### Speciale

| Livello | Tipo |
|---------|------|
| `UNKNOWN` | Livello firma non riconosciuto |
