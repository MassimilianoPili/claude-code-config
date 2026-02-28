# Moduli DSS - Riferimento Completo

31 dipendenze DSS dal `pom.xml` di `dss-wrapper/verifica-documenti-dss`.

## Core / Foundation

| Modulo | Artifact | Scopo |
|--------|----------|-------|
| **dss-model** | `dss-model` | Strutture dati base: `DSSDocument`, `InMemoryDocument`, `FileDocument`, `ToBeSigned`, `SignatureValue`, `Digest`, `DSSException` |
| **dss-enumerations** | `dss-enumerations` | Tutte le definizioni enum (99+): `SignatureLevel`, `DigestAlgorithm`, `Indication`, `SubIndication`, etc. |
| **dss-spi** | `dss-spi` | Service Provider Interface: processing ASN.1, calcolo digest, interfacce client HTTP |
| **dss-utils** | `dss-utils` | Interfacce utility |
| **dss-utils-apache-commons** | `dss-utils-apache-commons` | Implementazione utility basata su Apache Commons |
| **dss-utils-google-guava** | `dss-utils-google-guava` | Implementazione utility basata su Google Guava |
| **dss-alert** | `dss-alert` | Trigger e handler eventi per alert TL/LOTL |
| **dss-jaxb-common** | `dss-jaxb-common` | Data binding JAXB comune |
| **dss-document** | `dss-document` | Logica core firma/estensione/validazione documenti |
| **dss-service** | `dss-service` | Comunicazione risorse online: CRL/OCSP/TSP fetchers, `CommonsDataLoader`, `FileCacheDataLoader` |

## Formati Firma

| Modulo | Artifact | Scopo |
|--------|----------|-------|
| **dss-cades** | `dss-cades` | CAdES (CMS Advanced Electronic Signatures) - file `.p7m`, ETSI EN 319 122 |
| **dss-pades** | `dss-pades` | PAdES (PDF Advanced Electronic Signatures) - firme PDF embedded, ETSI EN 319 142 |
| **dss-pades-pdfbox** | `dss-pades-pdfbox` | Implementazione PAdES via Apache PDFBox |
| **dss-pades-openpdf** | `dss-pades-openpdf` | Implementazione PAdES via OpenPDF (fork iText) |
| **dss-asic-cades** | `dss-asic-cades` | Container ASiC con firme CAdES, ETSI EN 319 162 |

**Non usati nel progetto ma disponibili in DSS 5.12.1:**

| Modulo | Scopo |
|--------|-------|
| `dss-xades` | XAdES (XML Advanced Electronic Signatures), ETSI EN 319 132 |
| `dss-jades` | JAdES (JSON Advanced Electronic Signatures), ETSI TS 119 182 |
| `dss-asic-xades` | Container ASiC con firme XAdES |
| `dss-cms` | Utility CMS (RFC 5652) |

## Validazione e Trust

| Modulo | Artifact | Scopo |
|--------|----------|-------|
| **dss-tsl-validation** | `dss-tsl-validation` | Caricamento, parsing, validazione firma Trusted List (TL) e LOTL |
| **validation-policy** | `validation-policy` | Motore policy validazione XML (processing constraint.xml) |
| **specs-trusted-list** | `specs-trusted-list` | Modello JAXB per schema ETSI TS 119 612 Trusted List |
| **specs-validation-report** | `specs-validation-report` | Modello JAXB per ETSI TS 119 102-2 Validation Report |
| **dss-validation-server-common** | `dss-validation-server-common` | Utility validazione lato server |
| **dss-certificate-validation-common** | `dss-certificate-validation-common` | Logica validazione certificati |
| **dss-certificate-validation-dto** | `dss-certificate-validation-dto` | DTO validazione certificati |
| **dss-validation-dto** | `dss-validation-dto` | DTO request/response validazione |

## CRL / Revoca

| Modulo | Artifact | Scopo |
|--------|----------|-------|
| **dss-crl-parser** | `dss-crl-parser` | Parser CRL base |
| **dss-crl-parser-x509crl** | `dss-crl-parser-x509crl` | Parsing basato su oggetto Java `X509CRL` |
| **dss-crl-parser-stream** | `dss-crl-parser-stream` | Parser CRL streaming (efficiente in memoria per CRL grandi) |

## Remote / DTO

| Modulo | Artifact | Scopo |
|--------|----------|-------|
| **dss-common-remote-dto** | `dss-common-remote-dto` | DTO remoti condivisi |
| **dss-common-remote-converter** | `dss-common-remote-converter` | Convertitori DTO remoti |
| **dss-signature-remote** | `dss-signature-remote` | Servizio firma remoto |
| **dss-signature-dto** | `dss-signature-dto` | DTO creazione/augmentation firma |
| **dss-server-signing-common** | `dss-server-signing-common` | Firma lato server |
| **dss-server-signing-dto** | `dss-server-signing-dto` | DTO firma server |
| **dss-timestamp-remote** | `dss-timestamp-remote` | Servizio timestamp remoto |
| **dss-timestamp-dto** | `dss-timestamp-dto` | DTO operazioni timestamp |
