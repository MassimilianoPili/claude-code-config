# Algoritmi Crittografici DSS - Riferimento Completo

## DigestAlgorithm (16 valori)

Da enum `DigestAlgorithm` in `dss-enumerations`.

| Enum | Nome Java | OID | XML Identifier | Scadenza |
|------|-----------|-----|----------------|----------|
| `SHA1` | SHA-1 | 1.3.14.3.2.26 | xmldsig#sha1 | 2009 |
| `SHA224` | SHA-224 | 2.16.840.1.101.3.4.2.4 | xmldsig-more#sha224 | 2023 |
| `SHA256` | SHA-256 | 2.16.840.1.101.3.4.2.1 | xmlenc#sha256 | 2029* |
| `SHA384` | SHA-384 | 2.16.840.1.101.3.4.2.2 | xmldsig-more#sha384 | 2026 |
| `SHA512` | SHA-512 | 2.16.840.1.101.3.4.2.3 | xmlenc#sha512 | 2026 |
| `SHA3_224` | SHA3-224 | 2.16.840.1.101.3.4.2.7 | xmldsig-more#sha3-224 | 2026 |
| `SHA3_256` | SHA3-256 | 2.16.840.1.101.3.4.2.8 | xmldsig-more#sha3-256 | 2026 |
| `SHA3_384` | SHA3-384 | 2.16.840.1.101.3.4.2.9 | xmldsig-more#sha3-384 | 2026 |
| `SHA3_512` | SHA3-512 | 2.16.840.1.101.3.4.2.10 | xmldsig-more#sha3-512 | 2026 |
| `SHAKE128` | SHAKE-128 | 2.16.840.1.101.3.4.2.11 | - | - |
| `SHAKE256` | SHAKE-256 | 2.16.840.1.101.3.4.2.12 | - | - |
| `SHAKE256_512` | SHAKE256-512 | 2.16.840.1.101.3.4.2.18 | - | - |
| `RIPEMD160` | RIPEMD160 | 1.3.36.3.2.1 | xmlenc#ripemd160 | 2011 |
| `MD2` | MD2 | 1.2.840.113549.2.2 | xmldsig-more#md2 | 2005 |
| `MD5` | MD5 | 1.2.840.113549.2.5 | xmldsig-more#md5 | 2005 |
| `WHIRLPOOL` | WHIRLPOOL | 1.0.10118.3.0.55 | xmldsig-more#whirlpool | 2015 |

*SHA256 scadenza estesa a 2029 nel constraint.xml attuale (originale ETSI: 2026)

## EncryptionAlgorithm (9 valori)

Da enum `EncryptionAlgorithm` in `dss-enumerations`.

| Enum | OID | Nome Chiave | Padding |
|------|-----|-------------|---------|
| `RSA` | 1.2.840.113549.1.1.1 | RSA | RSA/ECB/PKCS1Padding |
| `RSASSA_PSS` | 1.2.840.113549.1.1.10 | RSASSA-PSS | RSA/ECB/OAEPPadding |
| `DSA` | 1.2.840.10040.4.1 | DSA | DSA |
| `ECDSA` | 1.2.840.10045.2.1 | ECDSA | ECDSA |
| `PLAIN_ECDSA` | 0.4.0.127.0.7.1.1.4.1 | PLAIN-ECDSA | PLAIN-ECDSA |
| `X25519` | 1.3.101.110 | X25519 | X25519 |
| `X448` | 1.3.101.111 | X448 | X448 |
| `EDDSA` | - | EdDSA | EdDSA |
| `HMAC` | - | HMAC | - |

**Algoritmi accettati nel progetto** (da constraint.xml): RSA, DSA, ECDSA, PLAIN-ECDSA

## Dimensioni Chiave Minime (da constraint.xml)

| Algoritmo | Dimensione Minima (bit) |
|-----------|------------------------|
| DSA | 1024 |
| RSA | 1024 |
| ECDSA | 160 |
| PLAIN-ECDSA | 160 |

## Date Scadenza Algoritmi Digest (da constraint.xml)

| Algoritmo | Scadenza | Riferimento ETSI | Stato |
|-----------|----------|------------------|-------|
| MD2 | 2005 | ETSI TS 102 176-1 V2.1.1 | Scaduto |
| MD5 | 2005 | ETSI TS 102 176-1 V2.1.1 | Scaduto |
| SHA1 | 2009 | ETSI TS 102 176-1 V2.0.0 | Scaduto |
| SHA224 | 2023 | ETSI 119 312 V1.3.1 | Scaduto |
| **SHA256** | **2029** | ETSI 119 312 V1.3.1 | **Attivo** |
| **SHA384** | **2026** | ETSI 119 312 V1.3.1 | **Attivo** |
| **SHA512** | **2026** | ETSI 119 312 V1.3.1 | **Attivo** |
| **SHA3-224** | **2026** | ETSI 119 312 V1.3.1 | **Attivo** |
| **SHA3-256** | **2026** | ETSI 119 312 V1.3.1 | **Attivo** |
| **SHA3-384** | **2026** | ETSI 119 312 V1.3.1 | **Attivo** |
| **SHA3-512** | **2026** | ETSI 119 312 V1.3.1 | **Attivo** |
| RIPEMD160 | 2011 | ETSI TS 102 176-1 V2.0.0 | Scaduto |
| WHIRLPOOL | 2015 | ETSI 119 312 V1.1.1 | Scaduto |

## Date Scadenza Algoritmi Cifratura (da constraint.xml)

| Algoritmo | Dimensione Chiave (bit) | Scadenza | Riferimento ETSI |
|-----------|------------------------|----------|------------------|
| **RSA** | 1024 | 2027 | ETSI TS 102 176-1 V2.0.0 |
| **RSA** | 1536 | 2027 | ETSI 119 312 V1.1.1 |
| **RSA** | 1900 | 2027 | ETSI 119 312 V1.3.1 |
| **RSA** | 3000 | 2029 | ETSI 119 312 V1.3.1 |
| **RSA** | 4096 | 2029 | ETSI 119 312 V1.3.1 |
| **DSA** | 1024 | 2026 | ETSI TS 102 176-1 V2.1.1 |
| **DSA** | 2048 | 2029 | ETSI 119 312 V1.3.1 |
| **ECDSA** | 160 | 2013 | ETSI 119 312 V1.1.1 |
| **ECDSA** | 224 | 2023 | ETSI 119 312 V1.1.1 |
| **ECDSA** | 256 | 2026 | ETSI 119 312 V1.3.1 |
| **ECDSA** | 384 | 2029 | ETSI 119 312 V1.3.1 |
| **ECDSA** | 512 | 2029 | ETSI 119 312 V1.3.1 |
| **PLAIN-ECDSA** | 160 | 2013 | ETSI 119 312 V1.1.1 |
| **PLAIN-ECDSA** | 224 | 2023 | ETSI 119 312 V1.1.1 |
| **PLAIN-ECDSA** | 256 | 2026 | ETSI 119 312 V1.3.1 |
| **PLAIN-ECDSA** | 384 | 2029 | ETSI 119 312 V1.3.1 |
| **PLAIN-ECDSA** | 512 | 2029 | ETSI 119 312 V1.3.1 |

## Note Importanti

- Le date nel constraint.xml attuale sono **estese** rispetto ai valori ETSI originali (es. RSA 1024 → 2027 invece di 2013)
- Il file `constraint_prod_fino_al_08_01_2026.xml` contiene le date ETSI originali piu' restrittive
- SHA256 con scadenza 2029 e' l'algoritmo digest principale raccomandato
- RSA 2048+ e ECDSA 256+ sono le combinazioni piu' sicure per uso a lungo termine
- Il progetto usa MD5 (`DigestAlgorithm.MD5`) solo per confronto hash documenti (`verificaMd5()`), non per validazione firme
