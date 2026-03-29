# Research: Case Study / Problem-Solution CV Formats for Software Engineers

## Executive Summary

The "case study CV" (also called "problem-solution" or "accomplishment-based" resume) is a format where each role is structured around specific challenges faced, actions taken, and results achieved, rather than a chronological list of duties. The evidence base for this specific format is surprisingly thin in peer-reviewed literature -- most academic resume research focuses on discrimination, bias, and ATS parsing rather than format comparison. However, by triangulating across eye-tracking studies, recruiter surveys, hiring manager interviews, ATS technical research, and practitioner literature, a clear picture emerges.

**Epistemic status:** Mix of established findings (eye-tracking, resume length) and practitioner consensus (case study format, metrics). No RCT directly compares case study vs chronological CVs for software engineers.
**Confidence:** Medium -- strong practitioner consensus supported by adjacent academic evidence, but no direct T1 study on the core question.

---

## 1. Effectiveness of Case Study CVs vs Chronological CVs

### What the academic literature says

**No peer-reviewed study directly compares "case study format" to "chronological format" for callback rates in tech hiring.** The resume audit study literature (Bertrand & Mullainathan 2004; Oreopoulos & Dechief 2012; Kessler, Low & Sullivan 2019 in AER) focuses on discrimination signals, not format variation. (T1 -- AER, NBER)

The closest relevant findings:

1. **Cole, Rubin, Feild & Giles (2007)** -- "Recruiters' perceptions and use of applicant resume information" (T1 -- Applied Psychology, Wiley). Found that recruiters form causal attributions from resume content. Accomplishment-oriented content (results, outcomes) was weighted more heavily than duty-based descriptions. Recruiters used resume information to infer **underlying traits** (initiative, competence), not just verify facts.

2. **Holst (2020)** -- "Identifying Recruiting Professionals' Practices During the Resume Evaluation Stage for Entry-Level IT Positions" (T3 -- Northeastern University dissertation). Found that for IT roles, recruiters focused on: (a) relevant technical skills, (b) demonstrated project outcomes, (c) evidence of problem-solving. The study used think-aloud protocols with 15 recruiting professionals and found that **quantified achievements** were a key differentiator in the "keep" vs "reject" decision.

3. **Loufek & Santos (2025)** -- "Beyond the Job Posting: What Hiring Managers Seek in Entry-Level Software Engineering Candidates" (T2 -- IEEE ICSE/CHASE 2025). Survey of 12 hiring managers. Key finding: managers valued **self-awareness** and **initiative** -- qualities that are better communicated through problem-solution narratives than through duty lists.

4. **Kuttal, Chen, Wang, Balali & Sarma (2021)** -- "Visual Resume: Exploring developers' online contributions for hiring" (T1 -- Information and Software Technology, Elsevier). Found that aggregating developers' contributions (commits, PRs, issues) into a structured visual format helped evaluators assess both technical and soft skills **more efficiently**. This supports the principle that structured, evidence-based presentation outperforms unstructured listing.

### Practitioner consensus (T5-T6 level)

The practitioner community (career coaches, tech hiring blogs, resume services) strongly favors accomplishment-based formats over duty-based ones. Key claims (not peer-reviewed but widely consistent):

- **ResumeGo (2019)** conducted a field experiment sending 7,712 resumes to real job openings. Two-page resumes received **2.3x more callbacks** than one-page resumes for candidates with 10+ years experience. While not testing case-study format per se, this suggests that more detail (which case-study format provides) is not penalized and may help. (T7 -- industry report, methodology not peer-reviewed but large N)

- **TheLadders (2012)** eye-tracking study with 30 recruiters found **average 7.4 seconds** initial scan time (widely misquoted as 6 seconds). Resumes with clear visual hierarchy and structured sections received longer attention in the "key areas." (T7 -- industry report, small N, not peer-reviewed, but frequently cited in academic work including Pina et al. 2023)

- **Pina, Petersheim, Cherian & Lahey (2023)** -- "Using machine learning with eye-tracking data to predict if a recruiter will approve a resume" (T2 -- Machine Learning and Knowledge Extraction, MDPI). Confirmed that even well-formatted resumes cannot compensate for weak content, but found that **clear formatting significantly affects where recruiters look and how long they spend** on key sections. GPA inclusion was less important than work experience sections.

### Bottom line on format effectiveness

**There is no RCT proving case-study format beats chronological for software engineers.** However, converging evidence suggests:
- Recruiters value quantified accomplishments over duty lists (Cole et al. 2007)
- Structured, evidence-based presentation improves evaluation efficiency (Kuttal et al. 2021)
- Hiring managers for SE roles specifically seek evidence of initiative and problem-solving (Loufek & Santos 2025)
- More detailed resumes (2 pages) do not hurt and may help senior candidates (ResumeGo 2019)

The case study format is the natural structural vehicle for all of these. The risk is ATS compatibility (see Section 5).

---

## 2. Best Practices for Quantifying Impact in Software Engineering CVs

### What resonates with hiring managers

Based on Holst (2020), Loufek & Santos (2025), the Ivanov et al. (2019) survey ("Recruiting Software Developers"), and Vaishampayan & Gulzar (2025, ICSE -- "Improving Evidence-Based Tech Hiring with GitHub-Supported Resume Matching"):

**Tier 1 metrics (strongest signal for hiring managers):**

| Metric | Why it works | Example |
|--------|-------------|---------|
| **Revenue/cost impact** | Directly quantifies business value | "Reduced cloud infrastructure costs by $240K/year through autoscaling optimization" |
| **Scale/throughput** | Demonstrates ability to handle production systems | "Designed system handling 50K req/s with p99 latency <100ms" |
| **Reliability/uptime** | Shows operational maturity | "Improved service availability from 99.9% to 99.99% (5.2 min downtime/year)" |
| **Team/delivery velocity** | Shows leadership and process improvement | "Reduced sprint cycle time from 3 weeks to 1 week; deployment frequency 4x" |

**Tier 2 metrics (good supporting evidence):**

| Metric | Why it works | Example |
|--------|-------------|---------|
| **Deployment frequency** | DORA metrics are well-known in industry | "Implemented CI/CD pipeline: deploys went from monthly to 15/day" |
| **Incident reduction** | Shows reliability engineering | "Reduced P1 incidents by 73% through observability stack redesign" |
| **Developer experience** | Increasingly valued | "Built internal tooling adopted by 200+ engineers, saving ~4 hrs/week each" |
| **Migration/modernization** | Common senior-level work | "Led migration of 3M LOC monolith to 47 microservices over 18 months" |

**Tier 3 metrics (weaker, use sparingly):**

| Metric | Risk | Better alternative |
|--------|------|-------------------|
| Lines of code | Goodhart's law; more code != better | Describe architectural decisions instead |
| Number of PRs | Quantity over quality signal | Describe impactful PRs |
| Test coverage % | Easily gamed | Describe testing strategy and outcomes |
| "Agile" buzzwords | Generic, everyone claims this | Describe specific process improvements |

### The XYZ formula (Google's recommendation)

Google's career team has publicly recommended the **XYZ formula**: "Accomplished [X] as measured by [Y], by doing [Z]."

Example: "Reduced page load time by 40% (from 3.2s to 1.9s) by implementing lazy loading and CDN edge caching."

This is essentially the written-CV adaptation of the STAR method (see Section 3).

### Key finding from Vaishampayan & Gulzar (2025)

This ICSE paper found that when resume claims could be cross-referenced with GitHub activity (commit frequency, code quality metrics from static analysis, PR review patterns), hiring decisions improved significantly. Implication: **quantified claims that are verifiable** (e.g., linking to open-source contributions) are more credible than unverifiable numbers.

---

## 3. Optimal CV Structure for Senior/Mid-Level Developers

### Resume Length: 1 Page vs 2 Pages

**Key study: Blackburn-Brockman & Belanger (2001)** -- "One Page or Two?: A National Study of CPA Recruiters' Preferences for Resume Length" (T1 -- Journal of Business Communication). N=570 Big Five accounting recruiters. Split-split-plot design with fictitious candidates. **Result: Two-page resumes ranked significantly more favorably** than one-page resumes, even for entry-level candidates.

**ResumeGo (2019) field experiment** (T7 -- not peer-reviewed, but N=7,712 real applications):
- Entry-level (<5 years): one-page slightly preferred (1.1x callback rate)
- Mid-level (5-10 years): two-page preferred (1.4x callback rate)
- Senior (10+ years): two-page strongly preferred (2.3x callback rate)

**Practitioner consensus:**
- 1 page: appropriate for <5 years of experience
- 2 pages: appropriate for 5+ years, especially if the second page contains relevant projects/impact
- 3+ pages: acceptable in Europe/UK/academia, frowned upon in US tech
- The "one page rule" appears to be a persistent myth not supported by empirical evidence for experienced candidates

### Skills-first vs Experience-first Ordering

No peer-reviewed study directly tests this for software engineering. Practitioner consensus:

**Skills-first (functional/hybrid) format:**
- Advantage: immediately shows technical stack match
- Advantage: good for career changers or those with non-linear paths
- Risk: ATS may struggle to associate skills with specific roles/time periods
- Risk: hiring managers may suspect you're hiding gaps

**Experience-first (reverse chronological) format:**
- Advantage: ATS parses this most reliably
- Advantage: hiring managers can quickly trace career trajectory
- Risk: buries skills if recent roles have generic titles

**Recommended hybrid approach** (practitioner consensus):
1. **Technical Skills Summary** (3-5 lines, keyword-dense for ATS) at top
2. **Professional Experience** in reverse chronological order, with each role using problem-solution bullets
3. **Key Projects / Case Studies** section (optional, for standout achievements that don't fit neatly under a single role)

This "hybrid" structure satisfies both ATS parsing (chronological skeleton) and human readers (case study content).

### STAR Method Adapted for Written CVs

The STAR (Situation, Task, Action, Result) method, originally an interview technique, adapts to written CVs as follows:

**Full STAR (for key achievements, 2-3 per role):**
> **[Situation/Task]** Inherited a legacy payment processing system with 12-hour batch cycles and frequent failures. **[Action]** Redesigned the pipeline using event-driven architecture (Kafka, PostgreSQL CDC), implemented circuit breakers and dead-letter queues. **[Result]** Reduced processing time from 12 hours to 45 minutes, eliminated 95% of manual interventions, saved ~$180K/year in operations costs.

**Compressed STAR (for supporting bullets):**
> Reduced API response times by 60% by profiling bottlenecks and implementing Redis caching layer (p95: 800ms -> 320ms)

The compressed form is more common in practice: it implies the situation (something was slow), states the action, and quantifies the result. The full form works well for 2-3 "headline" achievements per role.

### How ATS Handles Non-Chronological Formats (see also Section 5)

Key technical findings from ATS research (Chavan et al. 2024; Rawat et al. 2021 SLR on resume parsing):

- Most ATS systems use **section header detection** + **NER (Named Entity Recognition)** to parse resumes
- Chronological formats with standard headers ("Work Experience," "Education," "Skills") parse with highest accuracy
- Functional/case-study-only formats can cause ATS to **misclassify sections** or fail to associate skills with employers/dates
- Modern AI-powered ATS (2024+) using LLM-based parsing (Manchala et al. 2024, IEEE TENSYMP) are significantly better at handling non-standard formats, but older keyword-based systems still dominate the market

---

## 4. Case Study CV Examples and Templates from Reputable Sources

### Recommended approaches from tech-specific sources

**1. Laszlo Bock (former Google SVP of People Operations):**
In "Work Rules!" (2015) and multiple interviews, Bock recommends:
- Lead every bullet with an accomplishment, not a responsibility
- Use the XYZ formula (see Section 2)
- Quantify everything possible
- Keep it clean, no graphics/columns that confuse ATS

**2. Patrick McCuller (2012) -- "How to Recruit and Hire Great Software Engineers" (Apress):**
From the hiring manager's perspective: red flags include generic duty descriptions, technology name-dropping without context, and lack of measurable outcomes. Green flags: specific projects with scale indicators, technologies used in context, and clear individual contribution vs team achievement.

**3. Basecamp/37signals philosophy:**
Jason Fried has publicly stated Basecamp prefers cover letters and work samples over resumes. When they do look at resumes, they care about evidence of clear writing and independent thinking -- both naturally served by case study format.

**4. Stripe hiring:**
Stripe's engineering hiring (per public blog posts and ex-recruiter accounts) emphasizes "show the work" -- candidates who can articulate the problem, their specific contribution, and the outcome. Their resume screening reportedly favors candidates who describe systems they built and the tradeoffs they navigated.

### Template structure (synthesized from practitioner sources):

```
[NAME]
[Contact: email | phone | LinkedIn | GitHub]

=== TECHNICAL SKILLS ===
Languages: Java, Go, Python, TypeScript
Infrastructure: AWS (ECS, Lambda, DynamoDB), Kubernetes, Terraform
Practices: CI/CD, observability, distributed systems, event-driven architecture

=== PROFESSIONAL EXPERIENCE ===

COMPANY NAME -- Role Title (Month Year - Present)

[1-line company context if not well-known]

* [HEADLINE ACHIEVEMENT - full STAR]:
  Challenge: [1 sentence]. Solution: [1-2 sentences].
  Impact: [quantified result].

* [Supporting bullet - compressed STAR]
* [Supporting bullet - compressed STAR]

PREVIOUS COMPANY -- Role Title (Month Year - Month Year)
[Same pattern]

=== EDUCATION ===
[Degree, University, Year]

=== NOTABLE PROJECTS (optional) ===
[For open source, side projects, or cross-role achievements]
```

---

## 5. ATS Compatibility Concerns

### How ATS actually works (technical evidence)

Based on the 2024-2025 ATS research papers surveyed:

**Traditional ATS (still ~60-70% of market as of 2025):**
- Uses regex + keyword matching against job description
- Parses sections by header detection (expects standard headers)
- Extracts: name, contact, skills, work history (employer + dates), education
- **Failure modes with non-standard formats:**
  - Two-column layouts cause left/right text interleaving
  - Graphics, tables, and text boxes are invisible to parsers
  - Custom section headers ("Case Studies" instead of "Work Experience") may be ignored entirely
  - Skills listed outside a "Skills" section may not be indexed

**Modern AI-powered ATS (Greenhouse, Lever, Ashby -- growing market share):**
- Uses NLP/NER models (spaCy, BERT-based) for entity extraction
- Better at handling non-standard formats
- Can understand contextual skill mentions within experience descriptions
- Still benefits from standard headers as parsing anchors

**Key paper: Manchala et al. (2024)** -- "Optimizing Resume Parsing Processes by Leveraging LLMs" (T2 -- IEEE TENSYMP). Found that LLM-based parsing dramatically improves extraction from non-standard formats, but also found that **"highly qualified individuals may miss out on opportunities if their resumes are not formatted correctly"** for traditional systems.

**Baghbanzadeh & Wu (2025)** -- "Resume-Job Compatibility Scoring Using GNNs and LLMs" (ACM ICIT). Found 25% improvement in matching accuracy using semantic embeddings vs keyword matching. This is the direction ATS is moving, but traditional systems lag.

### Hybrid approach: ATS-safe case study format

The safe approach is a **chronological skeleton with case-study content**:

1. Use standard section headers: "Professional Experience," "Skills," "Education"
2. Within each role under Professional Experience, use problem-solution bullets (the case study content)
3. Include a keyword-rich "Technical Skills" section near the top (feeds ATS)
4. Avoid: columns, tables, graphics, headers/footers with contact info, PDF with image layers
5. File format: **plain .docx** for ATS submission; styled PDF only when submitting directly to humans

**Critical:** the role title, company name, and dates must be clearly parseable in a standard layout. The case study content goes *within* each chronological role entry, not as a separate section replacing the chronological structure.

---

## 6. European/Italian Market Specifics

### Europass format status

**No peer-reviewed study on Europass adoption rates in Italian tech hiring was found.** The following is based on practitioner knowledge and publicly available guidance:

**Europass (europass.europa.eu):**
- Launched by the EU in 2004, redesigned in 2020 (modernized layout)
- Still widely used in **public sector**, **government positions**, and **EU institutional** applications in Italy
- The 2020 redesign removed the old tabular format and allows more customization
- For many public administration positions in Italy, Europass is still **de facto required**

**Italian tech market reality (practitioner consensus, T7):**
- **Large Italian companies** (Intesa Sanpaolo tech, Poste Italiane digital, ENI, Leonardo): often expect Europass or at least accept it without penalty. HR departments may be less tech-savvy.
- **Italian startups and scale-ups** (e.g., Satispay, Bending Spoons, Scalapay): modern formats preferred, Europass seen as outdated/bureaucratic
- **International companies with Italian offices** (Google, Amazon, Microsoft, Stripe, Revolut): US-style resume strongly preferred
- **Remote-first/international roles**: US-style resume is standard
- **Consulting firms** (Accenture, Deloitte, Reply): either format acceptable, but accomplishment-based content valued

**Key differences US vs Europe:**

| Aspect | US Resume | European/Italian CV |
|--------|-----------|-------------------|
| Length | 1-2 pages strict | 2-3 pages acceptable |
| Photo | Never (discrimination concerns) | Common in Italy/Germany, declining in UK/NL |
| Personal info | Minimal (name, email, phone, LinkedIn) | May include date of birth, nationality, marital status (declining) |
| Privacy statement | Not needed | **Required in Italy** under GDPR: "Autorizzo il trattamento dei dati personali ai sensi del D.Lgs. 196/2003 e del GDPR (UE) 2016/679" |
| Format name | Resume | Curriculum Vitae (CV) |
| Cover letter | Often required | "Lettera di presentazione" -- expected for formal applications |
| Education | Bottom, brief | More prominent, especially for junior roles |

**Recommendation for the Italian tech market:**
- For Italian startups, international companies, remote roles: use a modern problem-solution format (no Europass)
- For Italian public sector or large traditional companies: use the 2020 Europass template but fill it with accomplishment-based content
- Always include the GDPR privacy authorization at the bottom
- Photo: optional, include only if applying to companies where it's customary (check their career page for signals)
- Language: English for international roles; Italian for domestic roles unless the job posting is in English

---

## Serendipitous Connections

**Preference learning / Bradley-Terry (Ranking Todo project):** The problem of ranking CV formats by effectiveness is structurally identical to preference learning -- hiring managers are performing pairwise comparisons (accept/reject) on resumes, which could be modeled as a Bradley-Terry process. The ResumeGo study essentially ran a large-scale audit study that could be reanalyzed with a BT model. Vaishampayan & Gulzar (2025) use similar ranking approaches for resume-job matching.

**Information extraction / NER (Kindle Graph Enrichment project):** ATS resume parsing is a direct application of the same NER pipeline used in knowledge graph construction. The ATS research papers (Manchala et al. 2024; Chavan et al. 2024) use the exact same stack (spaCy, BERT-based NER) that could be applied to extracting structured data from Kindle highlights or web content.

---

## Sources Fetched

### Academic (T1-T2)
1. Cole, Rubin, Feild & Giles (2007). "Recruiters' perceptions and use of applicant resume information." *Applied Psychology* (Wiley). URL: https://iaap-journals.onlinelibrary.wiley.com/doi/abs/10.1111/j.1464-0597.2007.00288.x
2. Blackburn-Brockman & Belanger (2001). "One Page or Two?: A National Study of CPA Recruiters' Preferences." *Journal of Business Communication*. DOI: 10.1177/002194360103800104
3. Kuttal, Chen, Wang, Balali & Sarma (2021). "Visual Resume: Exploring developers' online contributions for hiring." *Information and Software Technology* (Elsevier). URL: https://www.sciencedirect.com/science/article/pii/S0950584921001002
4. Kessler, Low & Sullivan (2019). "Incentivized resume rating: Eliciting employer preferences without deception." *American Economic Review*. URL: https://www.aeaweb.org/articles?id=10.1257/aer.20181714
5. Pina, Petersheim, Cherian & Lahey (2023). "Using ML with eye-tracking data to predict resume approval." *Machine Learning and Knowledge Extraction* (MDPI). URL: https://www.mdpi.com/2504-4990/5/3/38
6. Loufek & Santos (2025). "Beyond the Job Posting: What Hiring Managers Seek in Entry-Level SE Candidates." *IEEE ICSE/CHASE 2025*. URL: https://ieeexplore.ieee.org/abstract/document/11323277/
7. Vaishampayan & Gulzar (2025). "Improving Evidence-Based Tech Hiring with GitHub-Supported Resume Matching." *IEEE ICSE 2025*. URL: https://ieeexplore.ieee.org/abstract/document/10992573/
8. Fritzsch, Wyrich & Bogner (2021). "Resume-driven development: A definition and empirical characterization." *IEEE SANER*. arXiv:2101.12703
9. Setubal, Conte & Kalinowski (2024). "Investigating the online recruitment and selection journey of novice software engineers." *Empirical Software Engineering* (Springer). URL: https://link.springer.com/article/10.1007/s10664-024-10498-w

### ATS Technical (T2-T3)
10. Chavan et al. (2024). "Enhancing recruitment efficiency: An advanced ATS." *Industrial Management Advances*. DOI: 10.59429/ima.v2i1.6373
11. Manchala et al. (2024). "Optimizing Resume Parsing Processes by Leveraging LLMs." *IEEE TENSYMP*. DOI: 10.1109/TENSYMP61132.2024.10752300
12. Baghbanzadeh & Wu (2025). "Resume-Job Compatibility Scoring Using GNNs and LLMs." *ACM ICIT*. URL: http://dl.acm.org/citation.cfm?id=3787359
13. Rawat et al. (2021). "A SLR on Resume Parsing in HR Recruitment." Research Square preprint.

### Industry/Practitioner (T5-T7)
14. TheLadders (2012). Eye-tracking study. N=30, widely cited but not peer-reviewed.
15. ResumeGo (2019). Field experiment, N=7,712 applications. Not peer-reviewed.
16. McCuller (2012). "How to Recruit and Hire Great Software Engineers." Apress. DOI: 10.1007/978-1-4302-4918-4

### Dissertation (T3)
17. Holst (2020). "Identifying Recruiting Professionals' Practices During Resume Evaluation for Entry-Level IT Positions." Northeastern University dissertation.

---

## Open Questions

- **No RCT exists** comparing case-study vs chronological format for tech roles specifically. This would be a straightforward audit study to run (send matched pairs of resumes to real job openings).
- **ATS market share data** is proprietary. The claim that "60-70% of ATS is still keyword-based" is a practitioner estimate, not empirically verified.
- **European tech market** resume format preferences lack any systematic study. An audit study comparing Europass vs modern format for Italian tech roles would be novel.
- **The 7.4-second figure** from TheLadders is widely cited but methodologically weak (N=30, not peer-reviewed). The Pina et al. (2023) eye-tracking study with ML is more rigorous but doesn't directly report average screening time.
