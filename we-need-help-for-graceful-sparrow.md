# Plan: Culminating Activity — Predictive Analysis of Strava Activity Data

## Context

The user (a Predictive Analytics student) needs to draft Chapters 1–3 of a culminating R Markdown report ([Culminating Activity.Rmd](Culminating%20Activity.Rmd)) using a Strava activity dataset ([Strava Running Data.csv](Strava%20Running%20Data.csv), 105 records). The course covers supervised learning techniques from the two PDF chapters (Predictive Analytics – Supervised, Chapters 4 and 5), and the working file [Knn.Rmd](Knn.Rmd) shows they have already practiced **kNN classification, CART (classification + regression trees), confusion-matrix evaluation, train/test partitioning, feature scaling, and k-Means clustering** with `caret`, `class`, `rpart`, and `factoextra`.

User decisions captured this session:
- **Study direction:** Hybrid — Classification (predict activity type) **and** Regression (predict average speed).
- **Course framing:** Predictive Analytics / Data Science.
- **Out of scope for this turn:** Chapter 2 (Review of Related Literature) — the user will write it themselves; we only suggest article *types* to look up.

The plan below contains finished draft prose for each section so it can be pasted directly into the Rmd between the existing headings. Code chunks are provided where the methodology must be reproducible.

---

## Title (suggested)

> **Predicting Activity Type and Running Performance from Strava Wearable-Tracker Data: A Supervised Learning Approach Using kNN, CART, and Linear Regression**

---

## Abstract (drop-in, ~180 words)

This study applies supervised machine-learning techniques to a personal Strava activity log of 105 records to (1) classify the *type* of athletic activity (Run, Walk, Hike, Workout) and (2) predict the *average speed* of running activities. Distance, moving time, elapsed time, total elevation gain, and engagement metrics (kudos, achievements, athlete count) serve as predictors. k-Nearest Neighbors (kNN) and Classification and Regression Trees (CART) are used for the classification task, while multiple linear regression and regression-tree models are used for the speed-prediction task. Models are trained on a 70/30 stratified split, with numeric predictors centered and scaled. Performance is evaluated using accuracy, sensitivity, specificity, and the confusion matrix for classification, and using R², RMSE, and MAE for regression. Results are expected to confirm that distance and elevation gain are the strongest predictors of both activity type and running speed, and that CART provides interpretable decision rules suitable for fitness-application logic. Findings inform recommender features for self-tracking athletes and demonstrate the applicability of basic supervised learning to small wearable datasets.

---

## Chapter 1: Introduction

### 1.1 Background of the Study

Wearable fitness trackers and GPS-based activity platforms such as **Strava, Garmin Connect, Nike Run Club,** and **Apple Fitness** have transformed how individuals record and reflect on athletic activity. Each session captures dozens of telemetry features—distance, pace, elevation, moving time, geolocation, and social-engagement metrics—producing data streams that were previously available only to elite athletes with laboratory access. Globally, Strava reports more than 135 million users who collectively upload tens of millions of activities per week, making personal activity logs one of the largest sources of human-movement data in the world.

This abundance of data creates an opportunity for **predictive analytics**. Two questions are particularly relevant for both end-users and developers of fitness applications. First, can the *type* of activity (e.g., Run versus Walk versus Hike) be inferred from telemetry alone, without relying on the user's manual label? Automatic classification underlies features such as auto-pause, auto-detection of workouts, and personalized training feedback. Second, what factors *drive performance*, operationalized here as the average speed achieved during a run? Understanding the relative contribution of distance, terrain (elevation gain), and effort duration helps athletes plan training, set realistic pace goals, and recognise the trade-off between distance and pace.

The present study uses a personal Strava export (105 activities, December 2022 – December 2023, predominantly New York City) to demonstrate how introductory supervised-learning techniques—**k-Nearest Neighbors (kNN), Classification and Regression Trees (CART)**, and **multiple linear regression**—can answer both questions. The work follows the supervised-learning workflow taught in Chapters 4 and 5 of the course: data partitioning, preprocessing/scaling, model fitting, prediction, and confusion-matrix or error-metric evaluation.

### 1.2 Statement of the Problem

The general problem this study addresses is: *To what extent can simple supervised-learning algorithms accurately predict activity type and running performance from Strava telemetry?*

Specifically, the study seeks to answer:

1. What are the descriptive characteristics (central tendency, dispersion, distributional shape) of distance, moving time, elevation gain, average speed, and max speed across the 105 logged activities?
2. Is there a statistically significant relationship between **total elevation gain** and **average speed** in running activities?
3. How accurately can a **kNN classifier** predict the activity type (Run, Walk, Hike, Workout) given distance, moving time, elevation gain, average speed, and max speed?
4. How accurately can a **CART (decision-tree) classifier** predict activity type using the same predictors, and what split rules does it learn?
5. How well can **multiple linear regression** and a **regression tree** predict the average running speed from distance, elevation gain, moving time, and athlete count, and which predictors are most influential?
6. Which model — kNN, CART, or linear regression — performs best for its respective task, based on accuracy / RMSE on a held-out test set?

### 1.3 Objectives of the Study

#### General Objective
To develop, evaluate, and compare supervised machine-learning models that classify athletic activity type and predict average running speed using a Strava activity dataset.

#### Specific Objectives
1. **To describe** the dataset using descriptive statistics and exploratory visualisations (histograms, box-plots, scatter plots, correlation heat-map).
2. **To preprocess** the data by handling missing values, removing zero-distance records, encoding the activity-type factor, and centering/scaling numeric predictors.
3. **To partition** the data into training (70 %) and testing (30 %) subsets using stratified sampling on activity type.
4. **To build and evaluate** a kNN classifier for activity type, tuning *k* via cross-validation and reporting accuracy, sensitivity, specificity, and Cohen's kappa.
5. **To build and visualise** a CART decision-tree classifier for activity type and interpret its split rules.
6. **To build and evaluate** a multiple linear-regression model and a regression-tree (rpart, method = "anova") for predicting average running speed; report R², adjusted R², RMSE, and MAE.
7. **To compare** the predictive performance of the candidate models for each task and recommend the better-performing approach.

### 1.4 Hypotheses

For Specific Objective 2 (relationship between elevation and speed):

- **H₀₁:** There is no significant linear relationship between total elevation gain and average speed in running activities (β = 0).
- **H₁₁:** There is a significant negative linear relationship between total elevation gain and average speed (β < 0).

For Specific Objective 6 (model comparison – classification):

- **H₀₂:** kNN and CART achieve equal classification accuracy in predicting activity type.
- **H₁₂:** kNN and CART differ significantly in classification accuracy.

For Specific Objective 6 (model comparison – regression):

- **H₀₃:** Multiple linear regression and the regression tree achieve equal RMSE in predicting average running speed.
- **H₁₃:** The two regression methods differ significantly in RMSE.

All hypotheses are evaluated at the **α = 0.05** level of significance.

### 1.5 Significance of the Study

- **Self-tracking athletes** benefit from understanding which factors most influence their pace, helping them set realistic goals and plan training routes.
- **Fitness-application developers** gain insight into how lightweight ML models (kNN, CART) can power activity auto-detection and personalised feedback even on small per-user datasets.
- **Coaches and physical-education instructors** can use the descriptive findings to discuss the trade-off between elevation, distance, and pace.
- **Predictive-analytics students and educators** receive a worked, end-to-end example of the supervised-learning pipeline (split → preprocess → train → predict → evaluate) applied to a real, messy, real-world dataset rather than a textbook one.
- **Future researchers** can extend the methodology to larger multi-athlete Strava corpora, longitudinal training-load studies, or models that incorporate weather, heart-rate, and cadence data.

### 1.6 Scope and Limitations

**Scope.** The study is limited to one athlete's public Strava export covering **105 activities recorded between December 2022 and December 2023**, primarily in New York City (with a small number of activities in other US locations). Variables analysed are restricted to those present in the export: date, type/sport_type, distance (m), moving_time (s), elapsed_time (s), total_elevation_gain (m), start/end coordinates, average_speed (m/s), max_speed (m/s), and engagement counts (achievement, kudos, comment, athlete, photo). Models are limited to **kNN, CART, and multiple linear regression** as covered in Chapters 4 and 5.

**Limitations.**
1. **Single-athlete data** — findings cannot be generalised to other runners with different fitness levels, ages, or training programmes.
2. **Class imbalance** — the dataset is dominated by Runs (~80 %), with very few Walk, Hike, and Workout records, which limits the reliability of multiclass classification metrics.
3. **No physiological covariates** — heart-rate, cadence, weather, surface type, and shoe model are not in the export, so unexplained variance in speed will be substantial.
4. **One zero-distance / outlier record** (a Tennis "Workout" with 0 m and a Run with `elapsed_time = 62993 s`) is excluded from speed modelling.
5. **Small sample size (n = 105)** restricts model complexity; deep trees and high-k kNN are avoided to prevent overfitting.

---

## Chapter 2: Review of Related Literature — Suggested Article Types (the user will write this section)

You should search Google Scholar, ScienceDirect, IEEE Xplore, and arXiv for articles in **these five clusters** so that your literature review supports both the data and the methodology. For each cluster, the searched keywords are listed.

1. **Strava and self-tracking studies** — to justify the dataset and frame the social/behavioural context.
   - Keywords: *"Strava data analysis"*, *"quantified self"*, *"social fitness platform"*, *"running motivation kudos"*, *"GPS activity logging"*.

2. **Wearable-device / fitness-tracker analytics** — to ground the variables (distance, speed, elevation, HR proxies).
   - Keywords: *"wearable fitness tracker accuracy"*, *"GPS running data"*, *"activity recognition smartphone"*, *"consumer wearable validation"*.

3. **Running biomechanics & elevation–pace trade-off** — to support hypothesis H₁₁ (negative effect of elevation on speed).
   - Keywords: *"hill running pace"*, *"elevation gain running performance"*, *"grade-adjusted pace"*, *"running economy gradient"*.

4. **Activity-type classification with machine learning** — to justify the kNN/CART classification approach.
   - Keywords: *"human activity recognition kNN"*, *"decision tree activity classification"*, *"accelerometer activity recognition"*, *"sport classification GPS"*.

5. **Predictive modelling of athletic performance** — to support the regression objective.
   - Keywords: *"marathon time prediction regression"*, *"running pace prediction machine learning"*, *"CART sport science"*, *"endurance performance prediction"*.

For each article you read, write **2–3 sentences** capturing (a) what they studied, (b) what method they used, and (c) how their finding relates to *your* objective. Aim for **8–12 articles** total, and end the chapter with a paragraph that synthesises the gap your study fills (i.e., applying introductory supervised-learning methods to a single-athlete Strava export to address both classification and regression questions).

A brief **Conceptual Framework** diagram should follow the literature review:

```
[ Independent Variables ]                    [ Dependent Variables ]
distance, moving_time,           ┌──── kNN / CART ────►  Activity Type (categorical)
elapsed_time, elevation_gain,    │
max_speed, athlete_count   ──────┤
                                 └──── Lin. Regression / RegTree ──►  Average Speed (numeric)
```

---

## Chapter 3: Methodology (drop-in)

### 3.1 Research Design

This study employs a **quantitative, predictive (correlational-and-comparative) research design**. It is *quantitative* because all variables are numerical or categorical with finite levels; it is *predictive* because the primary aim is to forecast unseen outcomes (activity type, average speed) rather than merely describe; and it is *comparative* because two algorithms are pitted against each other for each task.

### 3.2 Data Collection

The dataset was obtained from a public **Strava** athlete export, distributed via Kaggle as `Strava Running Data.csv`. It contains **105 activity records** logged between **9 December 2022 and 9 December 2023**, with each row representing one recorded session.

```{r load-data}
library(tidyverse)
strava <- read.csv("Strava Running Data.csv", stringsAsFactors = FALSE)
dim(strava)
glimpse(strava)
```

### 3.3 Variables Description

| Role | Variable | Type | Unit | Description |
|---|---|---|---|---|
| ID | `Sr..no.` | integer | – | Activity row identifier |
| Date | `start_date_local` | datetime | ISO-8601 | Activity start time, athlete's local TZ |
| **Target (Classification)** | `type` / `sport_type` | factor | – | Run, Walk, Hike, Workout (Tennis) |
| **Target (Regression)** | `average_speed` | numeric | m/s | Mean speed during moving time |
| Predictor | `distance` | numeric | m | Total distance covered |
| Predictor | `moving_time` | numeric | s | Time actually moving |
| Predictor | `elapsed_time` | numeric | s | Total elapsed clock time |
| Predictor | `total_elevation_gain` | numeric | m | Cumulative climb |
| Predictor | `max_speed` | numeric | m/s | Peak speed during activity |
| Engagement | `achievement_count`, `kudos_count`, `comment_count`, `athlete_count`, `photo_count` | integer | – | Social/engagement metrics |
| Geo (descriptive only) | `start_latlng`, `end_latlng`, `timezone` | text | – | Location & TZ |

**Derived variables** that will be created during preprocessing:
- `pace_min_per_km = (moving_time/60) / (distance/1000)` — easier to interpret than m/s for runners.
- `is_run = factor(type == "Run")` — for an optional binary classification version, used to address class imbalance.
- `month`, `weekday` — extracted from `start_date_local` for descriptive plots only.

### 3.4 Data Preprocessing

```{r preprocess}
library(caret)

# 1. Drop rows with distance == 0 (e.g., the Tennis "Workout" row)
strava <- strava %>% filter(distance > 0)

# 2. Drop the obviously-erroneous elapsed_time outlier (62 993 s for a 1 304 m run)
strava <- strava %>% filter(elapsed_time < 30000)

# 3. Convert types
strava$type       <- factor(strava$type)
strava$sport_type <- factor(strava$sport_type)

# 4. Keep modelling variables only
model_df <- strava %>%
  select(type, distance, moving_time, elapsed_time,
         total_elevation_gain, average_speed, max_speed,
         athlete_count)
```

### 3.5 Train–Test Split

```{r split}
set.seed(123)
idx       <- createDataPartition(model_df$type, p = 0.7, list = FALSE)
train_set <- model_df[idx, ]
test_set  <- model_df[-idx, ]
```

### 3.6 Data Analysis Techniques

#### 3.6.1 Descriptive Statistics
- `summary()`, `psych::describe()` for mean, SD, median, IQR, skewness, kurtosis.
- Histograms, box-plots (per `type`), and a Pearson correlation heat-map (`corrplot`).

#### 3.6.2 Inferential Statistics
- **Pearson correlation** between `total_elevation_gain` and `average_speed` (runs only) — tests **H₀₁**.
- **Simple linear regression** of `average_speed ~ total_elevation_gain` reported alongside the correlation.
- **Paired evaluation** using McNemar's test on the test-set predictions of kNN vs. CART for **H₀₂**.
- **Paired t-test** on absolute residuals of the linear regression vs. the regression tree for **H₀₃**.

#### 3.6.3 Supervised Machine-Learning Models

**A. kNN Classifier (Activity Type)**

```{r knn}
library(class)
num_cols <- c("distance","moving_time","elapsed_time",
              "total_elevation_gain","average_speed","max_speed",
              "athlete_count")
preProc  <- preProcess(train_set[, num_cols], method = c("center","scale"))
train_s  <- predict(preProc, train_set[, num_cols])
test_s   <- predict(preProc, test_set[, num_cols])

# Tune k via 10-fold CV
ctrl <- trainControl(method = "cv", number = 10)
knn_tune <- train(x = train_s, y = train_set$type,
                  method = "knn", trControl = ctrl,
                  tuneGrid = expand.grid(k = seq(1, 15, 2)))
knn_pred <- predict(knn_tune, test_s)
confusionMatrix(knn_pred, test_set$type)
```

**B. CART Classifier (Activity Type)**

```{r cart-class}
library(rpart); library(rpart.plot)
cart_cls <- rpart(type ~ distance + moving_time + elapsed_time +
                  total_elevation_gain + average_speed + max_speed +
                  athlete_count,
                  data = train_set, method = "class")
rpart.plot(cart_cls, type = 2, extra = 104)
cart_pred <- predict(cart_cls, test_set, type = "class")
confusionMatrix(cart_pred, test_set$type)
```

**C. Multiple Linear Regression (Average Speed, Runs only)**

```{r lm}
runs <- model_df %>% filter(type == "Run")
set.seed(123)
ridx <- createDataPartition(runs$average_speed, p = 0.7, list = FALSE)
r_train <- runs[ridx, ]; r_test <- runs[-ridx, ]

lm_fit <- lm(average_speed ~ distance + moving_time +
             total_elevation_gain + athlete_count, data = r_train)
summary(lm_fit)
lm_pred <- predict(lm_fit, r_test)
postResample(lm_pred, r_test$average_speed)   # RMSE, R^2, MAE
```

**D. Regression Tree (Average Speed, Runs only)**

```{r rtree}
rt_fit  <- rpart(average_speed ~ distance + moving_time +
                 total_elevation_gain + athlete_count,
                 data = r_train, method = "anova")
rpart.plot(rt_fit, type = 2)
rt_pred <- predict(rt_fit, r_test)
postResample(rt_pred, r_test$average_speed)
```

#### 3.6.4 Model-Evaluation Metrics

| Task | Metric | Tool / Function |
|---|---|---|
| Classification | Accuracy, Sensitivity, Specificity, Kappa | `caret::confusionMatrix()` |
| Classification | Class-imbalance-robust comparison | McNemar's test |
| Regression | R², RMSE, MAE | `caret::postResample()` |
| Regression | Residual normality / homoscedasticity | `plot(lm_fit)` diagnostics |

#### 3.6.5 Software & Reproducibility
All analysis is performed in **R 4.x** within **RStudio** using **R Markdown**. Required packages: `tidyverse`, `caret`, `class`, `rpart`, `rpart.plot`, `corrplot`, `psych`, `ggplot2`. Random seed `set.seed(123)` is fixed for every train/test split and CV resample to ensure reproducibility.

---

## Files to be Modified

- `Culminating Activity.Rmd` — replace the placeholder text in *Abstract*, *Chapter 1* (sections 1.1–1.6), and *Chapter 3* (3.1–3.6) with the drop-in prose above and embed the four code chunks (kNN, CART, lm, rpart anova).
- `Strava Running Data.csv` — read-only; not modified.

## Reusable Functions Already Available
- `caret::createDataPartition` / `caret::preProcess` / `caret::train` / `caret::confusionMatrix` / `caret::postResample` (all already used in [Knn.Rmd](Knn.Rmd) lines 39–69).
- `class::knn`, `rpart::rpart`, `rpart.plot::rpart.plot` (all already loaded in [Knn.Rmd](Knn.Rmd) lines 18–25).

## Verification Plan
1. **Knit** `Culminating Activity.Rmd` to PDF and confirm there are no chunk errors.
2. Confirm `dim(strava)` after preprocessing returns roughly **103 rows × 8 columns** (105 minus the zero-distance Tennis row and the elapsed-time outlier).
3. Confirm `confusionMatrix(knn_pred, test_set$type)` and the CART confusion matrix print *Accuracy* ≥ 0.70 (sanity check; not a hard requirement).
4. Confirm `summary(lm_fit)` reports a significant negative coefficient on `total_elevation_gain` (consistent with H₁₁) **or** explicitly note in the discussion if it does not.
5. Confirm both `rpart.plot()` calls render trees without empty splits.
6. Spot-check one knit run with `set.seed(123)` removed to ensure no hidden state-dependence issues.

## Out of Scope (per user)
- Drafting the full Chapter 2 (Review of Related Literature) prose — only article-cluster suggestions were requested.
- Chapters 4 and 5 (Results, Discussion, Conclusion, Recommendations) — to be written *after* the analysis is run.

---

## Appendix A: Data-Fitness Diagnostic Script (`data_fitness_check.R`)

A standalone R script to run **before** the modelling step. It produces a "summary matrix" answering: *Is this dataset fit for kNN and CART?* Each check prints a PASS / WARN / FAIL verdict with a one-line reason, and the final block aggregates all verdicts into one data frame.

```r
# data_fitness_check.R --------------------------------------------------------
# Quick diagnostic: is Strava Running Data.csv fit for kNN and CART?
# Run with:  source("data_fitness_check.R")
# -----------------------------------------------------------------------------

required <- c("dplyr","psych","corrplot","caret","e1071")
new_pkgs <- required[!(required %in% installed.packages()[,"Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)
invisible(lapply(required, library, character.only = TRUE))

# 1. Load -------------------------------------------------------------------
strava <- read.csv("Strava Running Data.csv", stringsAsFactors = FALSE)
cat("Rows:", nrow(strava), " Cols:", ncol(strava), "\n\n")

# 2. Define modelling variables --------------------------------------------
target_cls <- "type"
target_reg <- "average_speed"
num_preds  <- c("distance","moving_time","elapsed_time",
                "total_elevation_gain","max_speed","athlete_count")

df <- strava %>%
  select(all_of(c(target_cls, target_reg, num_preds))) %>%
  filter(distance > 0, elapsed_time < 30000)        # remove obvious junk rows
df[[target_cls]] <- factor(df[[target_cls]])

verdicts <- list()
add <- function(check, status, note) {
  verdicts[[length(verdicts)+1]] <<- data.frame(
    check = check, status = status, note = note, stringsAsFactors = FALSE)
}

# 3. Sample size ------------------------------------------------------------
n <- nrow(df)
add("Sample size",
    ifelse(n >= 100, "PASS", ifelse(n >= 50, "WARN", "FAIL")),
    sprintf("n = %d (rule of thumb: >=100 for stable kNN/CART)", n))

# 4. Missing values ---------------------------------------------------------
na_total <- sum(is.na(df))
add("Missing values",
    ifelse(na_total == 0, "PASS", ifelse(na_total/prod(dim(df)) < 0.05,"WARN","FAIL")),
    sprintf("%d NA cells across the modelling frame", na_total))

# 5. Class distribution (classification feasibility) ------------------------
cls_tbl <- table(df[[target_cls]])
min_cls <- min(cls_tbl)
add("Class balance",
    ifelse(min_cls >= 10, "PASS", ifelse(min_cls >= 5, "WARN", "FAIL")),
    paste(names(cls_tbl), cls_tbl, sep = "=", collapse = ", "))
cat("Class counts:\n"); print(cls_tbl); cat("\n")

# 6. Near-zero-variance predictors -----------------------------------------
nzv <- nearZeroVar(df[, num_preds], saveMetrics = TRUE)
nzv_flag <- rownames(nzv)[nzv$nzv]
add("Near-zero variance",
    ifelse(length(nzv_flag) == 0, "PASS", "WARN"),
    ifelse(length(nzv_flag) == 0, "all predictors vary",
           paste("flagged:", paste(nzv_flag, collapse = ", "))))

# 7. Multicollinearity (Pearson r > 0.9) -----------------------------------
cor_mat <- cor(df[, num_preds], use = "pairwise.complete.obs")
hi <- which(abs(cor_mat) > 0.9 & lower.tri(cor_mat), arr.ind = TRUE)
hi_pairs <- if (nrow(hi)) apply(hi, 1, function(i)
                paste(rownames(cor_mat)[i[1]], colnames(cor_mat)[i[2]], sep="~")) else character(0)
add("Multicollinearity",
    ifelse(length(hi_pairs) == 0, "PASS", "WARN"),
    ifelse(length(hi_pairs) == 0, "max |r| <= 0.9",
           paste("|r|>0.9:", paste(hi_pairs, collapse = "; "))))
cat("Correlation matrix (numeric predictors):\n"); print(round(cor_mat, 2)); cat("\n")

# 8. Predictor scale (kNN sensitivity) -------------------------------------
ranges <- sapply(df[, num_preds], function(x) diff(range(x, na.rm = TRUE)))
ratio  <- max(ranges) / min(ranges[ranges > 0])
add("Predictor scales",
    ifelse(ratio <= 10, "PASS", "WARN"),
    sprintf("max/min range ratio = %.1f (kNN requires center+scale if >10)", ratio))

# 9. Skewness (CART tolerates, kNN sensitive) ------------------------------
sk <- sapply(df[, num_preds], e1071::skewness, na.rm = TRUE)
sk_bad <- names(sk)[abs(sk) > 2]
add("Skewness",
    ifelse(length(sk_bad) == 0, "PASS", "WARN"),
    ifelse(length(sk_bad) == 0, "all |skew| <= 2",
           paste("highly skewed:", paste(sk_bad, collapse = ", "))))

# 10. Outliers via IQR rule ------------------------------------------------
out_counts <- sapply(df[, num_preds], function(x) {
  q <- quantile(x, c(.25,.75), na.rm = TRUE); iqr <- diff(q)
  sum(x < q[1] - 1.5*iqr | x > q[2] + 1.5*iqr, na.rm = TRUE)
})
add("Outliers (IQR)",
    ifelse(max(out_counts) <= 0.05*n, "PASS", "WARN"),
    paste(names(out_counts), out_counts, sep="=", collapse=", "))

# 11. Target-predictor signal (regression target only) ---------------------
reg_cors <- sapply(df[, num_preds], function(x) cor(x, df[[target_reg]], use="pairwise"))
add("Regression signal",
    ifelse(max(abs(reg_cors)) >= 0.3, "PASS", "WARN"),
    sprintf("max |cor with avg_speed| = %.2f", max(abs(reg_cors))))
cat("|cor| with average_speed:\n"); print(round(sort(abs(reg_cors), decreasing = TRUE), 2)); cat("\n")

# 12. Curse-of-dimensionality check (kNN heuristic n >= 10*p) --------------
add("kNN dimensionality",
    ifelse(n >= 10 * length(num_preds), "PASS", "WARN"),
    sprintf("n=%d, p=%d (rule: n >= 10p)", n, length(num_preds)))

# 13. Aggregate matrix ------------------------------------------------------
fitness_matrix <- do.call(rbind, verdicts)
cat("\n================ DATA FITNESS SUMMARY ================\n")
print(fitness_matrix, row.names = FALSE)
cat("======================================================\n\n")

overall <- if (any(fitness_matrix$status == "FAIL"))      "NOT FIT"
           else if (any(fitness_matrix$status == "WARN")) "FIT WITH CAVEATS"
           else                                            "FULLY FIT"
cat("Overall verdict for kNN / CART modelling:", overall, "\n")
```

**How to interpret the matrix.**

| Verdict | Meaning |
|---|---|
| `PASS` | Check satisfied; safe to proceed. |
| `WARN` | Proceed but mention the caveat in Chapter 1.6 (Limitations) or Chapter 4 (Results). |
| `FAIL` | Address before modelling: re-clean the data, drop the variable, or switch method. |

**Expected results for this dataset (anticipated):**
- *Sample size*: WARN/PASS (n ≈ 103 after cleaning).
- *Class balance*: WARN/FAIL — Walk, Hike, Workout each have very few rows; this justifies the optional binary `is_run` framing in Chapter 1.6.
- *Multicollinearity*: WARN — `distance` and `moving_time` will be highly correlated (r ≈ 0.95+); plan to drop one for the linear regression.
- *Predictor scales*: WARN — `distance` (m, range ≈ 0–32 000) vs. `average_speed` (m/s, range ≈ 0–3) → mandatory `preProcess(method = c("center","scale"))` for kNN.
- *Skewness*: WARN on `distance` and `total_elevation_gain` → consider `log1p()` if linear-regression diagnostics misbehave.

The script's final printed line gives the **overall verdict** (`FULLY FIT`, `FIT WITH CAVEATS`, or `NOT FIT`) which becomes a one-paragraph paragraph in *Section 3.4 Data Preprocessing* of the Rmd report.

### Verification Plan (additional)
7. Run `source("data_fitness_check.R")` in the working directory and confirm the script completes without error and prints the *DATA FITNESS SUMMARY* table.
8. Confirm `overall` resolves to `"FIT WITH CAVEATS"` (or better) — anything worse means the modelling section needs to be revised before knitting.
