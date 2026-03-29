# Template F — Design Validation Report

Use when validating references and algorithmic choices in a technical design document.

**Report depth**: Each paper gets a **full validation block** with:
1. A `Claimed | Verified` comparison table (venue, year, citations)
2. A **Verdict** paragraph: how to correctly cite the paper, what to fix
3. A **Relevance to design** paragraph: critical assessment of whether the paper actually
   supports the design claim (not just name-matching)
4. **Source tier** label (T1-T7)

This depth prevents shallow validation (just checking if a paper exists) and catches the most
common errors: papers cited for claims they don't actually make, wrong venue attribution,
inflated citation counts from Google Scholar.

```markdown
# Design Validation Report: <ITEM NAME> (#<NUMBER>)

**Date:** <YYYY-MM-DD>
**Template:** F (Design Validation Report)

## Design Summary
<1 paragraph: what the item does, how it works>

---

## Reference Validation

### 1. Author "Title" (Year) — <Topic>

| Field | Claimed | Verified |
|-------|---------|----------|
| **Venue** | <claimed venue> | **CORRECT** / **INCORRECT — actual venue** |
| **Year** | <claimed year> | **CORRECT** / **INCORRECT** |
| **Citations** | ~N | **N2 (S2)** — <assessment: close / understated / inflated> |
| **Claim: <specific claim>** | <what design says> | **CORRECT** / **PARTIALLY INCORRECT** — <what paper actually shows> |

**Verdict:** <How to correctly cite this paper. What to fix in the design document.>

**Relevance to design:** <Critical assessment: does this paper actually support the design's
use case? Is the analogy loose or tight? What aspects map well vs poorly?>

**Source tier:** T? (<venue classification>)

---

### 2. Next Author "Title" (Year) — <Topic>
<same format>

---

## New Papers Found

1. **<Title>** (T? — Author et al., Venue Year, ~N cit S2, influential: M)
   - **Abstract:** <1-2 sentences>
   - **Relevance:** <why this matters for the design, what it adds beyond cited papers>

## Algorithmic Correctness

| Algorithm | Used for | Appropriate? | Alternative |
|-----------|----------|-------------|-------------|
| <algo> | <task> | yes / no | <correct algo if wrong> |

## Corrections

| # | What | From | To |
|---|------|------|----|
| 1 | <field> | <wrong value> | <correct value> |

## Recommendations
- <Concrete improvement to the design, grounded in literature>
```
