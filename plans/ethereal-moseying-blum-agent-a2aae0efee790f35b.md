# Plan: Write Bayesian Surprise Monitor Research Report (#136)

## Status: READY TO EXECUTE

## Research Completed
All sources fetched and validated. The report is ready to be written to:
`/data/massimiliano/docs/research/bayesian-surprise-136.md`

## Key Findings Summary

### Paper Validations
1. **Itti & Baldi "Bayesian surprise attracts human attention"**
   - CORRECTION: First appeared at NeurIPS 2005 (not 2009). The 2009 version is the journal paper in Vision Research (DOI: 10.1016/j.visres.2008.09.007). There is also a 2010 extended version "Of bits and wows" in Neural Networks.
   - 1709 citations, 145 influential (Semantic Scholar)

2. **Schmidhuber "Formal Theory of Creativity, Fun, and Intrinsic Motivation (1990-2010)"**
   - CONFIRMED: 2010, IEEE Transactions on Autonomous Mental Development
   - 849 citations, 38 influential

### New Papers Found
- Adams & MacKay, BOCPD (2007) — 850 citations, 152 influential
- Altamirano et al., Robust BOCPD (2023, ICML) — 24 citations
- Achiam & Sastry, Surprise-Based Intrinsic Motivation (2017) — 250 citations
- Aubret et al., Info-Theoretic IM Survey (2022, Entropy) — 53 citations
- Feldman & Friston, Attention/Uncertainty/Free-Energy (2010) — 1258 citations
- Huang et al., IAE-LSTM-KL anomaly detection (2024) — 7 citations
- Lee & Lee, SAD-KL semi-supervised anomaly (2022) — 8 citations

### Key Technical Answers
1. **KL direction**: KL(posterior || prior) IS the standard definition per Itti & Baldi and Feldman & Friston. This is correct.
2. **Adaptive thresholds**: Percentile-based is common but EVT (extreme value theory) approaches are more principled.
3. **Novelty/anomaly distinction**: Design choice with some support from RL literature (Aubret et al. 2022 survey). Not a standard result.
4. **Bayesian surprise vs simpler methods**: Surprise provides richer signal but higher computational cost. CUSUM and z-score are competitive for univariate streams.

## Execution Steps
1. Write the full research report to `/data/massimiliano/docs/research/bayesian-surprise-136.md`
   - Template A (Survey/Literature Review) format
   - All citations tier-labeled
   - All four key questions answered with evidence
   - Serendipitous connections section
   - Personal project connections noted
