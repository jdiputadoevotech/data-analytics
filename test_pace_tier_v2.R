# test_pace_tier_v2.R -------------------------------------------------------
# Improved kNN + CART + Random Forest classification of running PACE TIER.
# Improvements over test_pace_tier.R:
#   1. log1p() on skewed predictors (distance, elevation_gain) for kNN.
#   2. Wider k grid + weighted-kNN (kknn) for soft-vote near boundaries.
#   3. Repeated 10-fold CV (5 reps) for more stable tuning on small n.
#   4. CART cp tuned by CV (not default).
#   5. Random Forest as ceiling reference.
#   6. Drop athlete_count (low predictive signal).
# ---------------------------------------------------------------------------

needed <- c("tidyverse","caret","class","rpart","rpart.plot","kknn","randomForest","MLmetrics")
inst   <- needed[!(needed %in% installed.packages()[,"Package"])]
if (length(inst)) install.packages(inst, repos = "https://cloud.r-project.org")
invisible(lapply(needed, library, character.only = TRUE))

# 1. Load + clean ------------------------------------------------------------
strava <- read.csv("strava.csv", stringsAsFactors = FALSE) %>%
  drop_na() %>%
  filter(distance > 0, elapsed_time < 30000)
strava$type <- factor(strava$type)

runs <- strava %>% filter(type == "Run")

# 2. Pace tier ---------------------------------------------------------------
tert <- quantile(runs$average_speed, probs = c(0, 1/3, 2/3, 1))
runs$pace_tier <- cut(runs$average_speed, breaks = tert,
                     labels = c("Slow","Medium","Fast"), include.lowest = TRUE)

# 3. Feature engineering -----------------------------------------------------
#    log1p() compresses long right tails on distance and elevation -> better
#    Euclidean geometry for kNN.  rest_ratio captures stop-and-go behaviour
#    without referring to speed directly.
runs <- runs %>%
  mutate(
    log_distance      = log1p(distance),
    log_elevation     = log1p(total_elevation_gain),
    log_moving_time   = log1p(moving_time),
    rest_ratio        = (elapsed_time - moving_time) / elapsed_time
  )

model_df <- runs %>%
  select(pace_tier,
         log_distance, log_moving_time, log_elevation, rest_ratio)

cat("Pace-tier counts:\n"); print(table(model_df$pace_tier)); cat("\n")

# 4. Split -------------------------------------------------------------------
set.seed(123)
idx       <- createDataPartition(model_df$pace_tier, p = 0.7, list = FALSE)
train_set <- model_df[idx, ]
test_set  <- model_df[-idx, ]

num_cols <- setdiff(names(model_df), "pace_tier")
preProc  <- preProcess(train_set[, num_cols], method = c("center","scale"))
train_s  <- predict(preProc, train_set[, num_cols]); train_s$pace_tier <- train_set$pace_tier
test_s   <- predict(preProc, test_set[,  num_cols]); test_s$pace_tier  <- test_set$pace_tier

ctrl <- trainControl(method = "repeatedcv", number = 10, repeats = 5,
                     classProbs = TRUE, summaryFunction = multiClassSummary)

# 5. kNN (vanilla, wider grid) ----------------------------------------------
set.seed(123)
knn_fit <- train(pace_tier ~ ., data = train_s,
                 method = "knn",
                 trControl = ctrl,
                 tuneGrid = expand.grid(k = seq(1, 25, 2)),
                 metric = "Accuracy")

# 6. Weighted kNN (kknn): tunes k, distance, kernel -------------------------
set.seed(123)
kknn_fit <- train(pace_tier ~ ., data = train_s,
                  method = "kknn",
                  trControl = ctrl,
                  tuneGrid = expand.grid(
                    kmax     = seq(3, 21, 2),
                    distance = c(1, 2),                # Manhattan / Euclidean
                    kernel   = c("rectangular","triangular","gaussian")
                  ),
                  metric = "Accuracy")

# 7. CART with cp tuned -----------------------------------------------------
set.seed(123)
cart_fit <- train(pace_tier ~ ., data = train_s,
                  method = "rpart",
                  trControl = ctrl,
                  tuneGrid = expand.grid(cp = seq(0, 0.2, 0.01)),
                  metric = "Accuracy")

# 8. Random Forest ----------------------------------------------------------
set.seed(123)
rf_fit <- train(pace_tier ~ ., data = train_s,
                method = "rf",
                trControl = ctrl,
                tuneGrid = expand.grid(mtry = 1:4),
                ntree = 500,
                metric = "Accuracy")

# 9. Test-set evaluation ----------------------------------------------------
eval_one <- function(fit, name) {
  pred <- predict(fit, test_s)
  cm   <- confusionMatrix(pred, test_s$pace_tier)
  data.frame(
    model    = name,
    cv_acc   = max(fit$results$Accuracy, na.rm = TRUE),
    test_acc = unname(cm$overall["Accuracy"]),
    test_kap = unname(cm$overall["Kappa"])
  )
}

results <- bind_rows(
  eval_one(knn_fit,  "kNN (vanilla)"),
  eval_one(kknn_fit, "kNN (weighted)"),
  eval_one(cart_fit, "CART (tuned cp)"),
  eval_one(rf_fit,   "Random Forest")
)

cat("\n========== Best hyperparameters ==========\n")
cat("kNN k =", knn_fit$bestTune$k, "\n")
cat("kknn :"); print(kknn_fit$bestTune)
cat("CART cp =", cart_fit$bestTune$cp, "\n")
cat("RF mtry =", rf_fit$bestTune$mtry, "\n")

cat("\n========== Model comparison ==========\n")
print(results, row.names = FALSE, digits = 3)

# Naive baseline
baseline_acc <- max(prop.table(table(test_s$pace_tier)))
cat(sprintf("\nNaive majority-class baseline: %.3f\n", baseline_acc))

# 10. Confusion matrix of best model ----------------------------------------
best   <- results$model[which.max(results$test_acc)]
fit_lu <- list("kNN (vanilla)"=knn_fit, "kNN (weighted)"=kknn_fit,
               "CART (tuned cp)"=cart_fit, "Random Forest"=rf_fit)
cat(sprintf("\n========== Confusion matrix: %s ==========\n", best))
print(confusionMatrix(predict(fit_lu[[best]], test_s), test_s$pace_tier))

# 11. Variable importance for tree-based models -----------------------------
cat("\n========== CART variable importance ==========\n")
print(varImp(cart_fit))
cat("\n========== RF variable importance ==========\n")
print(varImp(rf_fit))
