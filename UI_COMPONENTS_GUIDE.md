# Banking Model Validation UI - Complete Guide

**Date:** May 8, 2026  
**Version:** 1.0  
**Purpose:** Comprehensive explanation of all UI components, calculations, and their relevance to model validation

---

## Table of Contents

1. [Validation Summary](#1-validation-summary)
2. [Statistical Tests](#2-statistical-tests)
3. [Performance Metrics](#3-performance-metrics)
4. [SR 11-7 Compliance](#4-sr-11-7-compliance)
5. [Model-Specific Validation](#5-model-specific-validation)

---

## 1. Validation Summary

### Overview
The top summary card provides a quick snapshot of the overall validation status and key metrics.

### Components

#### 1.1 Overall Status
**Display:** Colored chip (Green/Yellow/Red)  
**Values:** PASS, WARNING, FAIL  

**Calculation:**
```python
if compliance_score >= 70 and gini >= 0.3 and ks >= 0.25:
    status = "PASS"
elif compliance_score >= 50 or gini >= 0.2:
    status = "WARNING"
else:
    status = "FAIL"
```

**Meaning:**
- **PASS (Green):** Model meets all validation criteria
- **WARNING (Yellow):** Model has some concerns but may be acceptable
- **FAIL (Red):** Model does not meet minimum validation standards

**Relevance:**
- Quick decision-making for model approval
- Regulatory compliance indicator
- Risk management signal

---

#### 1.2 KS Statistic (Kolmogorov-Smirnov)
**Display:** Decimal number (0.0000 to 1.0000)  
**Example:** 0.1764

**Calculation:**
```python
# For each score threshold:
# 1. Calculate cumulative % of goods (non-defaults)
# 2. Calculate cumulative % of bads (defaults)
# 3. KS = max(|cumulative_goods% - cumulative_bads%|)

KS = max(abs(cumulative_good_rate - cumulative_bad_rate))
```

**Interpretation Thresholds:**
- **Excellent:** KS ≥ 0.40 (40%)
- **Good:** KS ≥ 0.30 (30%)
- **Acceptable:** KS ≥ 0.20 (20%)
- **Poor:** KS < 0.20 (20%)

**What It Means:**
- Measures the **maximum separation** between good and bad customers
- Higher KS = Better discrimination power
- KS of 0.40 means at some score cutoff, there's a 40% difference between cumulative good and bad rates

**Example:**
```
At score 650:
- 70% of goods have scores ≥ 650
- 30% of bads have scores ≥ 650
- Separation = 70% - 30% = 40% (KS = 0.40)
```

**Relevance for Model Validation:**
- **Primary discrimination metric** for credit scorecards
- Required by regulators (SR 11-7)
- Determines if model can effectively separate risk levels
- Used for setting approval cutoffs

---

#### 1.3 Gini Coefficient
**Display:** Decimal number (0.0000 to 1.0000)  
**Example:** 0.1830

**Calculation:**
```python
# Gini = 2 * AUC - 1
# Where AUC = Area Under ROC Curve

from sklearn.metrics import roc_auc_score
auc = roc_auc_score(y_true, y_pred_proba)
gini = 2 * auc - 1
```

**Interpretation Thresholds:**
- **Excellent:** Gini ≥ 0.60 (60%)
- **Good:** Gini ≥ 0.40 (40%)
- **Acceptable:** Gini ≥ 0.30 (30%)
- **Poor:** Gini < 0.30 (30%)

**What It Means:**
- Measures **overall model discrimination** across all score ranges
- Gini of 0.60 means model is 60% better than random
- Related to AUC: Gini = 2×AUC - 1

**Example:**
```
Gini = 0.40 (40%)
→ AUC = (0.40 + 1) / 2 = 0.70
→ Model is 70% accurate in ranking risk
```

**Relevance for Model Validation:**
- **Industry standard** for model performance
- Comparable across different models
- Used in model benchmarking
- Required for regulatory reporting

---

#### 1.4 Compliance Score
**Display:** Percentage (0% to 100%)  
**Example:** 58.33%

**Calculation:**
```python
# Weighted score across 9 SR 11-7 categories
compliance_score = sum(category_score * category_weight) / 100

# Example:
# Model Purpose (8%): 0/8 = 0.0
# Conceptual Soundness (15%): 10/15 = 10.0
# Data Quality (12%): 12/12 = 12.0
# ... (6 more categories)
# Total: 58.33%
```

**Interpretation Thresholds:**
- **Compliant:** Score ≥ 70%
- **Partial Compliance:** Score 50-69%
- **Non-Compliant:** Score < 50%

**What It Means:**
- Measures adherence to **SR 11-7 regulatory framework**
- Weighted score across 9 validation categories
- Each category has specific checks and requirements

**Relevance for Model Validation:**
- **Regulatory requirement** (Federal Reserve SR 11-7)
- Determines if model can be used in production
- Audit trail for regulators
- Risk management governance

---

## 2. Statistical Tests

### Overview
Detailed statistical analysis across three datasets: Train, Test, and Out-of-Time (OOT).

### Why Three Datasets?

**Train Dataset:**
- Data used to build/train the model
- Shows how well model fits training data
- Baseline performance

**Test Dataset:**
- Held-out data from same time period as training
- Tests model generalization
- Detects overfitting

**Out-of-Time (OOT) Dataset:**
- Data from future time period
- Tests model stability over time
- Most important for production readiness

---

### 2.1 KS Statistic (Per Dataset)

**Train KS:** 0.0596 (Poor)  
**Test KS:** 0.1764 (Poor)  
**OOT KS:** 0.1376 (Poor)

**What to Look For:**
```
✅ GOOD Pattern:
Train: 0.45, Test: 0.42, OOT: 0.40
→ Consistent, slight degradation acceptable

❌ BAD Pattern:
Train: 0.60, Test: 0.30, OOT: 0.25
→ Overfitting, poor generalization

❌ BAD Pattern (Current):
Train: 0.06, Test: 0.18, OOT: 0.14
→ Poor discrimination across all datasets
```

**Relevance:**
- Validates model **discrimination power**
- Detects overfitting (Train >> Test)
- Confirms temporal stability (Test ≈ OOT)

---

### 2.2 Gini Coefficient (Per Dataset)

**Train Gini:** 0.0117 (Poor)  
**Test Gini:** 0.1830 (Poor)  
**OOT Gini:** -0.0672 (Failed - Negative!)

**What to Look For:**
```
✅ GOOD Pattern:
Train: 0.65, Test: 0.62, OOT: 0.60
→ Strong, stable performance

❌ BAD Pattern (Current):
Train: 0.01, Test: 0.18, OOT: -0.07
→ Very poor, negative OOT means worse than random!
```

**Negative Gini Meaning:**
- Model is **worse than random guessing**
- Predictions are inversely correlated with outcomes
- **CRITICAL FAILURE** - Model cannot be used

**Relevance:**
- Overall model quality indicator
- Negative values indicate fundamental model failure
- Used for model comparison and selection

---

### 2.3 PSI (Population Stability Index)

**Train PSI:** 0.0000 (Stable)  
**Test PSI:** 0.0112 (Stable)  
**OOT PSI:** 0.0325 (Stable)

**Calculation:**
```python
# Compare score distributions between datasets
for each_bucket:
    expected_pct = train_distribution[bucket]
    actual_pct = test_distribution[bucket]
    psi_contribution = (actual_pct - expected_pct) * ln(actual_pct / expected_pct)

PSI = sum(psi_contributions)
```

**Interpretation Thresholds:**
- **Stable:** PSI < 0.10 (10%)
- **Moderate Shift:** PSI 0.10-0.25
- **Significant Shift:** PSI > 0.25

**What It Means:**
- Measures **population shift** between datasets
- Low PSI = Similar customer populations
- High PSI = Different customer mix

**Example:**
```
PSI = 0.03 (3%)
→ Test population is very similar to training
→ Model should perform consistently

PSI = 0.30 (30%)
→ Test population is significantly different
→ Model may not perform as expected
```

**Relevance:**
- Validates **model applicability** to new populations
- Detects data drift over time
- Triggers model retraining decisions
- Required for ongoing monitoring

---

### 2.4 CSI (Characteristic Stability Index)

**Train CSI:** 0.0000 (Stable)  
**Test CSI:** 0.0179 (Stable)  
**OOT CSI:** 0.0217 (Stable)

**Calculation:**
```python
# Average PSI across all model features
csi = average(psi_feature1, psi_feature2, ..., psi_featureN)

# Example:
# Age PSI: 0.0295
# Income PSI: 0.0130
# Credit History PSI: 0.0188
# CSI = (0.0295 + 0.0130 + 0.0188) / 3 = 0.0204
```

**Interpretation Thresholds:**
- **Stable:** CSI < 0.10
- **Moderate:** CSI 0.10-0.25
- **Unstable:** CSI > 0.25

**What It Means:**
- Measures **feature-level stability**
- Shows if input characteristics have changed
- More granular than PSI

**Relevance:**
- Identifies which features are drifting
- Guides feature engineering decisions
- Validates data quality over time
- Early warning system for model degradation

---

## 3. Performance Metrics

### Overview
Classification performance metrics across all three datasets.

---

### 3.1 Accuracy

**Train:** 48.6%  
**Test:** 50.2%  
**OOT:** 51.7%

**Calculation:**
```python
accuracy = (true_positives + true_negatives) / total_predictions

# Example:
# TP=61, TN=425, FP=469, FN=45, Total=1000
# Accuracy = (61 + 425) / 1000 = 48.6%
```

**Interpretation:**
- **Good:** > 70%
- **Acceptable:** 60-70%
- **Poor:** < 60%

**What It Means:**
- Percentage of **correct predictions**
- Simple but can be misleading with imbalanced data

**Why Current Values Are Low:**
```
Current: 48.6% - 51.7%
→ Model is barely better than random (50%)
→ Indicates poor predictive power
```

**Relevance:**
- Basic performance indicator
- Must be considered with other metrics
- Less important than Precision/Recall for credit models

---

### 3.2 Precision

**Train:** 11.51%  
**Test:** 12.03%  
**OOT:** 12.26%

**Calculation:**
```python
precision = true_positives / (true_positives + false_positives)

# Example (Train):
# TP=61, FP=469
# Precision = 61 / (61 + 469) = 11.51%
```

**Interpretation:**
- **Good:** > 50%
- **Acceptable:** 30-50%
- **Poor:** < 30%

**What It Means:**
- Of all customers predicted to **default**, what % actually defaulted?
- **"When model says YES, how often is it right?"**

**Example:**
```
Precision = 12%
→ Model predicts 100 customers will default
→ Only 12 actually default
→ 88 false alarms (good customers rejected)
```

**Relevance:**
- **Critical for credit decisions**
- Low precision = Many good customers rejected
- Impacts revenue (lost good customers)
- Balance with recall for optimal cutoff

---

### 3.3 Recall (Sensitivity)

**Train:** 57.55%  
**Test:** 68.09%  
**OOT:** 67.86%

**Calculation:**
```python
recall = true_positives / (true_positives + false_negatives)

# Example (Train):
# TP=61, FN=45
# Recall = 61 / (61 + 45) = 57.55%
```

**Interpretation:**
- **Good:** > 70%
- **Acceptable:** 50-70%
- **Poor:** < 50%

**What It Means:**
- Of all customers who **actually defaulted**, what % did model catch?
- **"How many bad customers does model catch?"**

**Example:**
```
Recall = 68%
→ 100 customers actually default
→ Model catches 68 of them
→ 32 bad customers slip through (approved)
```

**Relevance:**
- **Critical for risk management**
- Low recall = Many bad customers approved
- Impacts losses (defaults not prevented)
- Trade-off with precision

---

### 3.4 F1 Score

**Train:** 19.18%  
**Test:** 20.45%  
**OOT:** 20.77%

**Calculation:**
```python
f1_score = 2 * (precision * recall) / (precision + recall)

# Example (Train):
# Precision = 0.1151, Recall = 0.5755
# F1 = 2 * (0.1151 * 0.5755) / (0.1151 + 0.5755) = 0.1918 (19.18%)
```

**Interpretation:**
- **Good:** > 60%
- **Acceptable:** 40-60%
- **Poor:** < 40%

**What It Means:**
- **Harmonic mean** of Precision and Recall
- Balances both metrics
- Single score for model quality

**Why It's Low:**
```
Current: 19-21%
→ Very low precision (12%) drags down F1
→ Even though recall is moderate (68%)
→ Model struggles to balance both
```

**Relevance:**
- **Overall classification quality**
- Used for model comparison
- Guides threshold optimization
- Important for balanced decision-making

---

### 3.5 AUC-ROC (Area Under ROC Curve)

**Train:** 0.5054  
**Test:** 0.5491  
**OOT:** 0.6006

**Calculation:**
```python
from sklearn.metrics import roc_auc_score
auc = roc_auc_score(y_true, y_pred_probabilities)

# ROC Curve plots:
# X-axis: False Positive Rate (FPR)
# Y-axis: True Positive Rate (TPR/Recall)
# AUC = Area under this curve
```

**Interpretation:**
- **Excellent:** AUC > 0.80
- **Good:** AUC 0.70-0.80
- **Acceptable:** AUC 0.60-0.70
- **Poor:** AUC < 0.60
- **Random:** AUC = 0.50

**What It Means:**
- Probability that model ranks a **random defaulter higher** than a random non-defaulter
- AUC = 0.70 means 70% chance of correct ranking

**Current Values Analysis:**
```
Train: 0.5054 → Barely better than random
Test: 0.5491 → Still very poor
OOT: 0.6006 → Acceptable but concerning pattern
```

**Relevance:**
- **Threshold-independent** performance measure
- Compares models fairly
- Related to Gini: Gini = 2×AUC - 1
- Industry standard metric

---

## 4. SR 11-7 Compliance

### Overview
Federal Reserve SR 11-7 guidance requires comprehensive model validation across 9 categories.

---

### 4.1 The 9 SR 11-7 Categories

#### Category 1: Model Purpose (Weight: 8%)
**Current Score:** 0/8 (Failed)

**What It Checks:**
- Clear documentation of model purpose
- Defined use cases
- Business alignment

**Why It Matters:**
- Ensures model is used appropriately
- Prevents model misuse
- Regulatory requirement

**How to Pass:**
- Document model objectives
- Define target population
- Specify decision framework

---

#### Category 2: Conceptual Soundness (Weight: 15%)
**Current Score:** 10/15 (Partial)

**What It Checks:**
- Theoretical foundation documented
- Methodology appropriateness
- Assumptions validated

**Why It Matters:**
- Validates model logic
- Ensures scientific rigor
- Builds stakeholder confidence

**How to Pass:**
- Document statistical methodology
- Justify variable selection
- Validate all assumptions

---

#### Category 3: Data Quality (Weight: 12%)
**Current Score:** 12/12 (Passed)

**What It Checks:**
- Data completeness (100%)
- Data accuracy (90%+)
- Data representativeness

**Why It Matters:**
- **"Garbage in, garbage out"**
- Foundation of model reliability
- Regulatory focus area

**Calculation:**
```python
completeness = 1 - (missing_values / total_values)
accuracy = data_quality_score  # From validation checks
representativeness = population_coverage_score
```

---

#### Category 4: Performance Validation (Weight: 15%)
**Current Score:** 5/15 (Partial)

**What It Checks:**
- Discrimination power (Gini ≥ 0.30)
- Calibration (KS ≥ 0.25)
- Performance metrics calculated

**Why It Matters:**
- **Core validation requirement**
- Determines model effectiveness
- Risk management foundation

**Current Issues:**
```
Gini: 0.183 < 0.30 (Failed)
KS: 0.176 < 0.25 (Failed)
→ Model doesn't meet minimum standards
```

---

#### Category 5: Stability Analysis (Weight: 12%)
**Current Score:** 12/12 (Passed)

**What It Checks:**
- PSI analysis performed
- CSI analysis performed
- Overall stability assessed

**Why It Matters:**
- Validates temporal consistency
- Detects population drift
- Guides monitoring strategy

**Current Status:**
```
PSI: 0.0112 < 0.10 (Stable) ✓
CSI: 0.0179 < 0.10 (Stable) ✓
→ Population is stable
```

---

#### Category 6: Assumptions Testing (Weight: 10%)
**Current Score:** 10/10 (Passed)

**What It Checks:**
- Assumptions documented
- Assumptions tested
- Sensitivity analysis performed

**Why It Matters:**
- Validates model foundations
- Identifies model limitations
- Supports model governance

---

#### Category 7: Implementation Validation (Weight: 8%)
**Current Score:** 2.67/8 (Partial)

**What It Checks:**
- Implementation verified
- Production testing completed
- Rollback plan documented

**Why It Matters:**
- Ensures correct deployment
- Prevents production errors
- Risk mitigation

---

#### Category 8: Ongoing Monitoring (Weight: 10%)
**Current Score:** 3.33/10 (Partial)

**What It Checks:**
- Monitoring plan defined
- Drift detection implemented
- Revalidation schedule defined

**Why It Matters:**
- **Continuous validation**
- Early warning system
- Regulatory requirement

---

#### Category 9: Documentation (Weight: 10%)
**Current Score:** 3.33/10 (Partial)

**What It Checks:**
- Model documentation complete
- Validation report generated
- Audit trail maintained

**Why It Matters:**
- Regulatory compliance
- Knowledge transfer
- Audit readiness

---

### 4.2 Compliance Score Calculation

```python
# Weighted sum across all categories
compliance_score = (
    model_purpose_score * 0.08 +
    conceptual_soundness_score * 0.15 +
    data_quality_score * 0.12 +
    performance_validation_score * 0.15 +
    stability_analysis_score * 0.12 +
    assumptions_testing_score * 0.10 +
    implementation_validation_score * 0.08 +
    ongoing_monitoring_score * 0.10 +
    documentation_score * 0.10
)

# Current Example:
compliance_score = (
    0.0 * 0.08 +      # 0/8
    10.0 * 0.15 +     # 10/15
    12.0 * 0.12 +     # 12/12
    5.0 * 0.15 +      # 5/15
    12.0 * 0.12 +     # 12/12
    10.0 * 0.10 +     # 10/10
    2.67 * 0.08 +     # 2.67/8
    3.33 * 0.10 +     # 3.33/10
    3.33 * 0.10       # 3.33/10
) = 58.33%
```

---

### 4.3 Recommendations

The system provides actionable recommendations based on gaps:

**Example Recommendations:**
1. "Enhance theoretical foundation documentation and methodology justification"
2. "Conduct comprehensive performance testing with multiple metrics"
3. "Establish monitoring plan with drift detection and revalidation schedule"
4. "Complete all required documentation sections and maintain audit trail"
5. "Document model purpose, use cases, and business alignment clearly"
6. "Verify implementation and establish production testing procedures"

**How to Use:**
- Prioritize by category weight
- Address failed categories first
- Track progress over time
- Document remediation actions

---

## 5. Model-Specific Validation

### Overview
Additional validation checks specific to the model type (Application, Behavioral, Collections).

---

### 5.1 Validation Type

**Display:** "Application Scorecard"

**Types:**
- **Application Scorecard:** New customer acquisition
- **Behavioral Scorecard:** Existing customer management
- **Collections Early Stage:** Recent delinquencies
- **Collections Late Stage:** Serious delinquencies

**Relevance:**
- Different models have different requirements
- Tailored validation approach
- Specific performance thresholds

---

### 5.2 Use Case

**Display:** "Credit Origination / New Customer Acquisition"

**What It Means:**
- Defines model's intended purpose
- Determines validation criteria
- Guides performance expectations

**Examples:**
- Credit Origination: Approve/Decline decisions
- Line Management: Credit limit adjustments
- Collections: Recovery strategy selection

---

### 5.3 Status

**Display:** Colored chip showing overall model-specific validation status

**Values:**
- **Passed:** All model-specific checks passed
- **Partial:** Some checks passed
- **Failed:** Critical checks failed

**Relevance:**
- Quick assessment of model readiness
- Highlights model-specific issues
- Guides remediation efforts

---

## Summary: How to Use This UI

### For Model Validators

1. **Start with Summary:**
   - Check overall status
   - Review key metrics (KS, Gini, Compliance)

2. **Dive into Statistical Tests:**
   - Compare Train/Test/OOT performance
   - Look for overfitting or degradation
   - Check stability (PSI/CSI)

3. **Review Performance Metrics:**
   - Assess classification quality
   - Balance Precision vs Recall
   - Consider business impact

4. **Check Compliance:**
   - Identify gaps
   - Prioritize remediation
   - Document findings

5. **Review Model-Specific:**
   - Validate use case alignment
   - Check type-specific requirements

### For Model Managers

1. **Focus on Summary:**
   - Overall status for approval decisions
   - Compliance score for regulatory reporting

2. **Review Recommendations:**
   - Understand gaps
   - Plan remediation
   - Allocate resources

3. **Monitor Trends:**
   - Compare with previous validations
   - Track improvement over time

### For Auditors

1. **Verify Compliance:**
   - Check all 9 SR 11-7 categories
   - Review documentation completeness
   - Validate audit trail

2. **Assess Performance:**
   - Verify metrics meet thresholds
   - Check stability over time
   - Review testing methodology

3. **Review Recommendations:**
   - Assess management response
   - Track remediation progress

---

## Glossary

**AUC-ROC:** Area Under Receiver Operating Characteristic Curve  
**CSI:** Characteristic Stability Index  
**F1 Score:** Harmonic mean of Precision and Recall  
**Gini:** Measure of model discrimination (2×AUC - 1)  
**KS:** Kolmogorov-Smirnov statistic  
**OOT:** Out-of-Time (future data)  
**Precision:** True Positives / (True Positives + False Positives)  
**PSI:** Population Stability Index  
**Recall:** True Positives / (True Positives + False Negatives)  
**SR 11-7:** Federal Reserve guidance on model risk management  

---

**Document Version:** 1.0  
**Last Updated:** May 8, 2026  
**Author:** Banking Model Validation System  
**Status:** Production Ready