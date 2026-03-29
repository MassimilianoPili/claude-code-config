# Spring Boot Migration - Note Specifiche Progetto DC

Questo file contiene le note e i fix specifici per la migrazione del progetto DC (Diritti Civili).

---

## MICROSERVIZI MIGRATI

| Microservizio | Status | Note |
|---------------|--------|------|
| dc-profiler-ms | Completato | Pilot - SB 3.2.2 / Java 17 |
| dc-common-security-lib | Completato | 1.1.0-SNAPSHOT |
| dc-legal-interest-lib | Completato | 1.1.0-SNAPSHOT |
| dc-document-engine-lib | Completato | 1.1.1-SNAPSHOT |
| dc-exporter-lib | Completato | 1.1.1-SNAPSHOT |
| dc-auditing-sql-lib | Completato | 1.1.0-SNAPSHOT |
| dc-cvcs-ms | Completato | SB 3.2.2 / Java 17 - Oracle |
| dc-ideg-ms | Completato | SB 3.2.2 / Java 17 - MongoDB |
| dc-cedu-ms | Completato | SB 3.2.2 / Java 17 - HYBRID (MongoDB + Oracle) |

### dc-ideg-ms - Fix Applicati

| File | Problema | Soluzione |
|------|----------|-----------|
| TbBeneficiario.java | `@Temporal` su MongoDB doc | Rimosso |
| TbNotificationCronConfig.java | `nonapi.io.github.classgraph.json.Id` | → `org.springframework.data.annotation.Id` |
| CustomNamespacePrefixMapper.java | `com.sun.xml.bind.marshaller` | → `org.glassfish.jaxb.runtime.marshaller` |
| PignoramentoPreStepGenericImpl.java | Import `Guard` non usato | Rimosso |
| ModelloComunicazioneController.java | `Base64.decode()` | → `Base64.getDecoder().decode()` |
| UcbServiceImpl.java | `Base64.decode/encode()` | → `Base64.getDecoder/getEncoder()` |
| FascicoloRepositoryImpl.java | `liquibase.util.file.FilenameUtils` | → `org.apache.commons.io.FilenameUtils` |
| pom.xml | liquibase-mongodb 4.27.0 | → 5.0.1 |

### dc-cedu-ms - Fix Applicati

| File | Problema | Soluzione |
|------|----------|-----------|
| DRelAvvProvRepository.java | Hibernate 6 entity comparison in JOIN ON | Usa implicit join: `JOIN rap.fkSequIdSoggetto s` |
| DRelSogBenProvRepository.java | Hibernate 6 entity comparison in JOIN ON | Usa implicit join: `JOIN rap.fkSequIdSoggetto s` |
| DRelAvvRicRepository.java | Hibernate 6 entity comparison in JOIN ON | Usa implicit join: `JOIN rap.fkSequIdSoggetto s` |
| DRelProvSogRicRepository.java | Hibernate 6 entity comparison in JOIN ON | Usa implicit join: `JOIN rap.fkSequIdSoggetto s` |
| DRelSogRicRicRepository.java | Hibernate 6 entity comparison in JOIN ON | Usa implicit join: `JOIN rap.fkSequIdSoggetto s` |

**Nota:** Tutti i repository usavano explicit JOIN con ON clause (`JOIN Entity e ON relationship = e.id`). Hibernate 6 non permette confronto tra `@ManyToOne` entity e primitive. Fix: usare implicit join navigation (`JOIN relationship alias`).

---

## HIBERNATE 6 / ORACLE - FIX SPECIFICI

Per progetti Oracle/JPA, Hibernate 6 e' **molto piu' strict** di Hibernate 5. Questi errori appaiono solo a runtime.

### 1. @Embeddable mancante su classi PK

**Errore:**
```
NullPointerException: Cannot invoke "...XClass.isAnnotationPresent()" because "embeddableClass" is null
```

**Causa:** Hibernate 5 tollerava PK senza `@Embeddable`. Hibernate 6 lo richiede.

**Fix:** Aggiungere `@Embeddable` a tutte le classi usate con `@EmbeddedId`:
```java
import jakarta.persistence.Embeddable;

@Embeddable  // AGGIUNGERE
@Data
public class MyEntityPk implements Serializable { ... }
```

### 2. Conflitto @Id + @EmbeddedId

**Errore:** Stesso NPE di sopra ma l'entity ha sia `@Id` che `@EmbeddedId`.

**Causa:** JPA non permette entrambi nella stessa entity.

**Fix:** Cambiare `@EmbeddedId` → `@Embedded` quando esiste gia' un `@Id` separato:
```java
@Id
private Long historyId;

@Embedded  // era @EmbeddedId - CAMBIARE
private MyEntityPk originalPk;
```

### 3. HQL JOIN ON cross-entity

**Errore:**
```
SqmQualifiedJoin predicate referred to SqmRoot [Entity(a)] other than the join's root [Entity(b)]
```

**Causa:** In Hibernate 6, un JOIN ON deve riferirsi solo all'entita' a cui si attacca.

**Fix:** Ristrutturare la query mettendo tutti i JOIN espliciti subito dopo l'entita' base, poi i cross-joins:
```java
// PRIMA (invalido)
FROM TbInstance i, TpInstance it, TpLawOfReference lof
LEFT JOIN TpPriorityRecord tppr ON i.tpPriorityRecordId = tppr.id  // ERRORE: ON riferisce 'i' ma JOIN attaccato a 'lof'

// DOPO (corretto)
FROM TbInstance i
LEFT JOIN TpPriorityRecord tppr ON tppr.id = i.tpPriorityRecordId  // JOIN subito dopo 'i'
, TpInstance it, TpLawOfReference lof  // Cross-join DOPO
WHERE i.tpInstanceId = it.id AND i.tpLawOfReference = lof.id
```

### 4. TRUNC() su date Oracle

**Errore:**
```
FunctionArgumentException: Parameter 1 of function 'trunc()' has type 'NUMERIC', but argument is of type 'java.sql.Timestamp'
```

**Causa:** Hibernate 6 interpreta `TRUNC()` come funzione numerica SQL standard.

**Fix:** Creare custom Hibernate function `trunc_date()`:

**File:** `config/HibernateFunctionsConfig.java`
```java
package com.accenture.[service].config;

import org.hibernate.boot.model.FunctionContributions;
import org.hibernate.boot.model.FunctionContributor;
import org.hibernate.type.StandardBasicTypes;

public class HibernateFunctionsConfig implements FunctionContributor {
    @Override
    public void contributeFunctions(FunctionContributions functionContributions) {
        // trunc_date(campo) -> TRUNC(campo) returning DATE
        functionContributions.getFunctionRegistry().registerPattern(
                "trunc_date",
                "TRUNC(?1)",
                functionContributions.getTypeConfiguration().getBasicTypeRegistry()
                        .resolve(StandardBasicTypes.DATE));

        // oracle_sysdate() -> SYSDATE returning TIMESTAMP
        functionContributions.getFunctionRegistry().registerPattern(
                "oracle_sysdate",
                "SYSDATE",
                functionContributions.getTypeConfiguration().getBasicTypeRegistry()
                        .resolve(StandardBasicTypes.TIMESTAMP));

        // add_days(campo, days) -> (campo + days) returning TIMESTAMP
        // Bypassa il requisito TemporalAmount di Hibernate 6
        functionContributions.getFunctionRegistry().registerPattern(
                "add_days",
                "(?1 + ?2)",
                functionContributions.getTypeConfiguration().getBasicTypeRegistry()
                        .resolve(StandardBasicTypes.TIMESTAMP));
    }
}
```

**File:** `resources/META-INF/services/org.hibernate.boot.model.FunctionContributor`
```
com.accenture.[service].config.HibernateFunctionsConfig
```

**Usage in HQL:**
```java
// PRIMA
WHERE tdd.nosEndDate < TRUNC(SYSDATE)

// DOPO
WHERE tdd.nosEndDate < trunc_date(current_date)
```

### 5. Aritmetica date con parametri numerici

**Errore:**
```
SemanticException: Operand of + is of type 'java.lang.Integer' which is not a temporal amount
```

**Causa:** Hibernate 6 richiede `TemporalAmount` per aritmetica date, non Integer/Double.

**Fix con add_days():**
```java
// PRIMA (Integer meetingDuration in minuti)
m.dateTime + :meetingDuration/1440

// DOPO (Double meetingDurationDays precalcolato)
add_days(m.dateTime, :meetingDurationDays)

// Nel service che chiama:
Double meetingDurationDays = meetingDuration / 1440.0;
repository.findMethod(..., meetingDurationDays, ...);
```

### 6. CURRENT_DATE + ?1 parametro numerico

**Errore:**
```
SemanticException: Cannot compare left expression of type 'java.sql.Timestamp' with right expression of type 'java.time.Duration'
```

**Fix:** Convertire a native query:
```java
// PRIMA (HQL)
@Query("... WHERE dd.nosEndDate <= CURRENT_DATE + ?1 ...")
List<UserRoleRTO> find(Double days);

// DOPO (Native + Projection)
@Query(value = "SELECT ... WHERE dd.NOS_END_DATE <= CURRENT_DATE + ?1 ...", nativeQuery = true)
List<UserRoleProjection> find(Double days);

// Creare interface projection
public interface UserRoleProjection {
    String getName();
    String getSurname();
    // ... getter per ogni colonna alias
}
```

### 7. Literal temporale in HQL

Per intervalli fissi, usare la sintassi literal:
```java
// PRIMA
campo + 1  // Hibernate 5 interpretava come giorni

// DOPO
campo + 1 day
(current_timestamp - 1 day)
```

---

## CHECKLIST HIBERNATE 6 (Oracle/JPA)

Prima dell'avvio dell'applicazione, verificare:

- [ ] Tutte le classi PK hanno `@Embeddable`
- [ ] Nessuna entity ha sia `@Id` che `@EmbeddedId`
- [ ] Query HQL: JOIN ON riferisce solo l'entita' a cui e' attaccato
- [ ] Query HQL: Nessun `TRUNC()` diretto (usare `trunc_date()`)
- [ ] Query HQL: Nessuna aritmetica date con Integer/Double (usare `add_days()`)
- [ ] ServiceLoader registrato per HibernateFunctionsConfig
- [ ] Nessun alias duplicato nelle query HQL
- [ ] Confronti Boolean in HQL usano `IS TRUE`/`IS FALSE` (non `= 'S'`/`= 'N'`)
- [ ] JOIN tra campi di tipo diverso usano CAST (es. `CAST(pm.year AS string)`)

---

## 8. Integer vs String type mismatch in JOIN

**Errore:**
```
SemanticException: Cannot compare left expression of type 'java.lang.Integer' with right expression of type 'java.lang.String'
```

**Causa:** Entity A ha campo `Integer`, Entity B ha campo `String`. Hibernate 6 non fa cast automatico.

**Esempio dc-cvcs-ms:**
```java
// PRIMA (TbPaymentDecreeRepository.java:66)
JOIN TbPaymentMonth pmonth ON pm.memberFiscalCode = pmonth.user
  AND pm.tpBimester = pmonth.tpBimester
  AND pm.year = pmonth.year  // pm.year è Integer, pmonth.year è String

// DOPO
JOIN TbPaymentMonth pmonth ON pm.memberFiscalCode = pmonth.user
  AND pm.tpBimester = pmonth.tpBimester
  AND CAST(pm.year AS string) = pmonth.year
```

---

## 9. Boolean field vs String literal comparison

**Errore:**
```
SemanticException: Cannot compare left expression of type 'java.lang.Boolean' with right expression of type 'java.lang.String'
```

**Causa:** Campo entity e' `Boolean` ma HQL confronta con `'S'`/`'N'` (legacy Oracle CHAR).

**Fix Patterns:**

```java
// Pattern 1: Confronto diretto
// PRIMA
WHERE field = 'S'
WHERE field = 'N'

// DOPO
WHERE field IS TRUE
WHERE field IS FALSE

// Pattern 2: CASE expression
// PRIMA
CASE WHEN field = 'S' THEN ... ELSE ... END

// DOPO (se campo gia' Boolean)
CASE WHEN field IS TRUE THEN ... ELSE ... END
// oppure usare il campo direttamente se possibile

// Pattern 3: Parametro boolean
// PRIMA
AND :isSecretServices = true

// DOPO
AND :isSecretServices IS TRUE
```

**Esempio dc-cvcs-ms (MvCppoInstanceDataRepository.java:138):**
```java
// PRIMA
"AND ((:isSecretServices = true AND mv.flagSecretService = 'S') OR (:isSecretServices = false AND (mv.flagSecretService IS NULL OR mv.flagSecretService <> 'S')))"

// DOPO
"AND ((:isSecretServices IS TRUE AND mv.flagSecretService IS TRUE) OR (:isSecretServices IS FALSE AND (mv.flagSecretService IS NULL OR mv.flagSecretService IS FALSE)))"
```

---

## 10. Alias collision in HQL

**Errore:**
```
AliasCollisionException: Alias [od] used for multiple from-clause elements : TbOpinionDocument(od), TbOpinionDetailNoBlob(od)
```

**Causa:** Stesso alias usato per entita' diverse nella stessa query. Spesso errore di copy-paste.

**Esempio dc-cvcs-ms (TbOpinionDocumentSignatureRepository.java):**
```java
// PRIMA (alias 'od' duplicato)
"JOIN TbOpinionDocument od ON ods.tbOpinionDocument = od.id "
"JOIN TbOpinion o ON o.id = od.tbOpinion "
"JOIN TbOpinionDetailNoBlob od on od.id = o.tbOpinionDetailId "  // DUPLICATO!
"JOIN TbMeeting m on m.id = od.tbMeeting "

// DOPO (rinominato in 'odnb')
"JOIN TbOpinionDocument od ON ods.tbOpinionDocument = od.id "
"JOIN TbOpinion o ON o.id = od.tbOpinion "
"JOIN TbOpinionDetailNoBlob odnb on odnb.id = o.tbOpinionDetailId "
"JOIN TbMeeting m on m.id = odnb.tbMeeting "
```

---

## 11. Invalid path on simple @Id

**Errore:**
```
SemanticException: Could not interpret path expression 'e.id.tbAnaAuthorityCode'
```

**Causa:** L'entity ha un `@Id` semplice (Long), non composito. Hibernate 6 non permette navigazione `id.campo` su @Id semplici.

**Esempio dc-cvcs-ms (TbPdsEnteCodiceFiscaleRepository.java:24-25):**
```java
// PRIMA (e.id e' un Long semplice, tbAnaAuthorityCode e' colonna separata)
"WHERE e.id.tbAnaAuthorityCode = :tbAnaAuthorityCode "

// DOPO
"WHERE e.tbAnaAuthorityCode = :tbAnaAuthorityCode "
```

---

## dc-cvcs-ms - FIX APPLICATI (SESSION RECENTI)

| File | Linea | Problema | Soluzione |
|------|-------|----------|-----------|
| TbPaymentDecreeRepository.java | 66, 101 | Integer vs String in JOIN | `CAST(pm.year AS string)` |
| TbPdsEnteCodiceFiscaleRepository.java | 24-25 | Invalid path on simple @Id | `e.id.tbAnaAuthorityCode` → `e.tbAnaAuthorityCode` |
| MvCppoInstanceDataRepository.java | 65, 137-138 | Boolean vs String literal | `= 'S'` → `IS TRUE`, `= 'N'` → `IS FALSE` |
| TbOpinionDocumentSignatureRepository.java | 80-81, 107-108 | Alias collision `od` | Rinominato in `odnb` per TbOpinionDetailNoBlob |
| TbAutomaticAssignmentConfigRepository.java | 27-32 | JOIN ON cross-entity | Ristrutturato FROM clause |
| TbInstanceRoleRepository.java | 373 | Boolean param comparison | `:isSecretServices = true` → `IS TRUE` |
| TbInstanceFilterSearchRepository.java | 66 | Boolean param comparison | `:isSecretServices = true` → `IS TRUE` |
| TbInstanceRepository.java | 686, 705, 720, 735 | Boolean param comparison | `:isSecretServices = true/false` → `IS TRUE/FALSE` |