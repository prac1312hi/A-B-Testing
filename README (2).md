# A/B Test Analysis: One-Page Checkout

End-to-end analysis of an A/B test on an e-commerce checkout redesign: from sample-size planning and data cleaning to significance testing, segment analysis and a launch recommendation.

**Tools:** Python (pandas, NumPy, SciPy, Matplotlib), SQL (SQLite / MySQL-compatible), Jupyter

## Business question
ShopNest (a fictional online store) replaced its multi-step checkout with a single-page checkout. Does the new design increase purchases, and is it safe to roll out to all users?

## Key results

| Metric | Control (old) | Treatment (new) | Change |
|---|---|---|---|
| Conversion rate | 11.47% | 12.87% | **+1.39 pp (+12.1%)**, p < 0.001 |
| 95% CI for lift | | | +0.97 pp to +1.82 pp |
| Revenue per user | ₹177.70 | ₹201.84 | **+₹24.15 (+13.6%)**, p < 0.001 |
| Average order value | ₹1,549 | ₹1,569 | no significant change (p = 0.25) |

![Conversion by group](images/conversion_by_group.png)

- **Mobile users drive the gain** (+1.9 pp); the desktop effect is small and not statistically significant, but there's no sign of harm.
- A small **novelty effect** in week 1, but the lift holds in weeks 2–3.
- Estimated impact: **+1,260 to +1,810 extra orders per month (about ₹20–28 lakh)**.

**Recommendation:** roll out to 100% of users, keep a 5% holdout for 4 weeks, and monitor payment-failure and refund rates.

![Lift by segment](images/lift_by_segment.png)

## What the analysis covers
1. **Test design:** hypotheses, metrics, sample-size / power calculation (25,714 users per group for a 0.8 pp minimum detectable effect)
2. **Data cleaning:** removed duplicate logs, group/page mismatches, and users exposed to both versions (1.3% of users)
3. **Sample Ratio Mismatch (SRM) check:** chi-square test on the 50/50 split
4. **Primary metric:** two-proportion z-test with confidence interval (implemented from scratch)
5. **Revenue:** Welch's t-test plus a bootstrap confidence interval for skewed data
6. **Segments:** device and new/returning users, with Bonferroni correction for multiple testing
7. **Time stability:** daily and cumulative conversion, week 1 vs later weeks
8. **Business impact and recommendation**

## Repository structure
```
├── ab_test_analysis.ipynb   # full analysis with outputs
├── sql/ab_test_queries.sql  # data-quality checks, clean view, metrics, segments (CTEs, window functions)
├── generate_data.py         # creates the synthetic dataset
├── data/ab_test_data.csv    # 92,736 rows
├── images/                  # charts
└── requirements.txt
```

## How to run
```bash
pip install -r requirements.txt
python generate_data.py          # optional, data is already included
jupyter notebook ab_test_analysis.ipynb
```

## Note on the data
The dataset is synthetic, generated to reflect a realistic e-commerce test, including messy logging (duplicates, mismatched assignments, users in both groups) so that cleaning is part of the analysis.
