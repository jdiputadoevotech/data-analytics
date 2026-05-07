# data_fitness_check.R --------------------------------------------------------
# Quick diagnostic: is "Strava Running Data.csv" fit for kNN and CART?
#
# Run with:
#   setwd("c:/Users/Janritch/OneDrive/Documents/Rmarkdown")
#   source("data_fitness_check.R")
#
# Produces a PASS / WARN / FAIL summary matrix and an overall verdict.
# -----------------------------------------------------------------------------

required <- c("dplyr", "psych", "corrplot", "caret", "e1071")
new_pkgs <- required[!(required %in% installed.packages()[, "Package"])]
if (length(new_pkgs)) install.packages(new_pkgs)
invisible(lapply(required, library, character.only = TRUE))
# use here() to reliably locate the dataset without changing the working dir
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
library(here)

# 1. Load -------------------------------------------------------------------
# read the dataset using a project-root relative path via here()
strava <- read.csv(here::here("Strava Running Data.csv"), stringsAsFactors = FALSE)
cat("Raw rows:", nrow(strava), " Cols:", ncol(strava), "\n\n")

# 2. Define modelling variables --------------------------------------------
target_cls <- "type"
target_reg <- "average_speed"
num_preds  <- c("distance", "moving_time", "elapsed_time",
                "total_elevation_gain", "max_speed", "athlete_count")

df <- strava %>%
  select(all_of(c(target_cls, target_reg, num_preds))) %>%
  filter(distance > 0, elapsed_time < 30000)        # remove obvious junk rows
df[[target_cls]] <- factor(df[[target_cls]])

cat("Rows after cleaning:", nrow(df), "\n\n")

verdicts <- list()
add <- function(check, status, note) {
  verdicts[[length(verdicts) + 1]] <<- data.frame(
    check  = check,
    status = status,
    note   = note,
    stringsAsFactors = FALSE
  )
}

# 3. Sample size ------------------------------------------------------------
n <- nrow(df)
add("Sample size",
    ifelse(n >= 100, "PASS", ifelse(n >= 50, "WARN", "FAIL")),
    sprintf("n = %d (rule of thumb: >= 100 for stable kNN/CART)", n))

# 4. Missing values ---------------------------------------------------------
na_total <- sum(is.na(df))
add("Missing values",
    ifelse(na_total == 0, "PASS",
           ifelse(na_total / prod(dim(df)) < 0.05, "WARN", "FAIL")),
    sprintf("%d NA cells across the modelling frame", na_total))

# 5. Class distribution (classification feasibility) ------------------------
cls_tbl <- table(df[[target_cls]])
min_cls <- min(cls_tbl)
add("Class balance",
    ifelse(min_cls >= 10, "PASS",
           ifelse(min_cls >= 5, "WARN", "FAIL")),
    paste(names(cls_tbl), cls_tbl, sep = "=", collapse = ", "))
cat("Class counts:\n"); print(cls_tbl); cat("\n")

# 6. Near-zero-variance predictors -----------------------------------------
nzv      <- nearZeroVar(df[, num_preds], saveMetrics = TRUE)
nzv_flag <- rownames(nzv)[nzv$nzv]
add("Near-zero variance",
    ifelse(length(nzv_flag) == 0, "PASS", "WARN"),
    ifelse(length(nzv_flag) == 0, "all predictors vary",
           paste("flagged:", paste(nzv_flag, collapse = ", "))))

# 7. Multicollinearity (Pearson |r| > 0.9) ---------------------------------
cor_mat  <- cor(df[, num_preds], use = "pairwise.complete.obs")
hi       <- which(abs(cor_mat) > 0.9 & lower.tri(cor_mat), arr.ind = TRUE)
hi_pairs <- if (nrow(hi))
  apply(hi, 1, function(i) paste(rownames(cor_mat)[i[1]],
                                 colnames(cor_mat)[i[2]], sep = "~"))
else character(0)
add("Multicollinearity",
    ifelse(length(hi_pairs) == 0, "PASS", "WARN"),
    ifelse(length(hi_pairs) == 0, "max |r| <= 0.9",
           paste("|r|>0.9:", paste(hi_pairs, collapse = "; "))))
cat("Correlation matrix (numeric predictors):\n")
print(round(cor_mat, 2)); cat("\n")

# 8. Predictor scale (kNN sensitivity) -------------------------------------
ranges <- sapply(df[, num_preds], function(x) diff(range(x, na.rm = TRUE)))
ratio  <- max(ranges) / min(ranges[ranges > 0])
add("Predictor scales",
    ifelse(ratio <= 10, "PASS", "WARN"),
    sprintf("max/min range ratio = %.1f (kNN requires center+scale if > 10)",
            ratio))

# 9. Skewness (CART tolerates, kNN sensitive) ------------------------------
sk     <- sapply(df[, num_preds], e1071::skewness, na.rm = TRUE)
sk_bad <- names(sk)[abs(sk) > 2]
add("Skewness",
    ifelse(length(sk_bad) == 0, "PASS", "WARN"),
    ifelse(length(sk_bad) == 0, "all |skew| <= 2",
           paste("highly skewed:", paste(sk_bad, collapse = ", "))))

# 10. Outliers via IQR rule ------------------------------------------------
out_counts <- sapply(df[, num_preds], function(x) {
  q   <- quantile(x, c(.25, .75), na.rm = TRUE)
  iqr <- diff(q)
  sum(x < q[1] - 1.5 * iqr | x > q[2] + 1.5 * iqr, na.rm = TRUE)
})
add("Outliers (IQR)",
    ifelse(max(out_counts) <= 0.05 * n, "PASS", "WARN"),
    paste(names(out_counts), out_counts, sep = "=", collapse = ", "))

# 11. Target-predictor signal (regression target) --------------------------
reg_cors <- sapply(df[, num_preds],
                   function(x) cor(x, df[[target_reg]], use = "pairwise"))
add("Regression signal",
    ifelse(max(abs(reg_cors)) >= 0.3, "PASS", "WARN"),
    sprintf("max |cor with average_speed| = %.2f", max(abs(reg_cors))))
cat("|cor| with average_speed:\n")
print(round(sort(abs(reg_cors), decreasing = TRUE), 2)); cat("\n")

# 12. Curse-of-dimensionality (kNN heuristic n >= 10*p) --------------------
add("kNN dimensionality",
    ifelse(n >= 10 * length(num_preds), "PASS", "WARN"),
    sprintf("n = %d, p = %d (rule: n >= 10p)", n, length(num_preds)))

# 13. Aggregate matrix ------------------------------------------------------
fitness_matrix <- do.call(rbind, verdicts)
cat("\n================ DATA FITNESS SUMMARY ================\n")
print(fitness_matrix, row.names = FALSE)
cat("======================================================\n\n")

overall <- if (any(fitness_matrix$status == "FAIL")) {
  "NOT FIT"
} else if (any(fitness_matrix$status == "WARN")) {
  "FIT WITH CAVEATS"
} else {
  "FULLY FIT"
}
cat("Overall verdict for kNN / CART modelling:", overall, "\n")
