# test_pace_tier.R ----------------------------------------------------------
# kNN + CART classification of running PACE TIER (Slow / Medium / Fast)
# Reframe of the original multiclass `type` task, which failed due to
# severe class imbalance (Run = 94, Workout = 7, Walk = 3, Hike = 1).
# ---------------------------------------------------------------------------

library(tidyverse)
library(caret)
library(class)
library(rpart)
library(rpart.plot)

# 1. Load --------------------------------------------------------------------
strava <- read.csv("strava.csv", stringsAsFactors = FALSE)
cat("Raw rows:", nrow(strava), "  cols:", ncol(strava), "\n\n")

# 2. Clean -------------------------------------------------------------------
strava <- strava %>%
  drop_na() %>%
  filter(distance > 0) %>%        # drop Tennis 0 m row
  filter(elapsed_time < 30000)    # drop 62 993 s logging-noise row

strava$type <- factor(strava$type)
cat("Original class counts:\n"); print(table(strava$type)); cat("\n")

# 3. Restrict to Runs --------------------------------------------------------
runs <- strava %>% filter(type == "Run")
cat("Runs after cleaning:", nrow(runs), "\n\n")

# 4. Derive balanced pace tier from average_speed tertiles -------------------
tert <- quantile(runs$average_speed, probs = c(0, 1/3, 2/3, 1), na.rm = TRUE)
runs$pace_tier <- cut(
  runs$average_speed,
  breaks         = tert,
  labels         = c("Slow", "Medium", "Fast"),
  include.lowest = TRUE
)
cat("Pace-tier distribution:\n"); print(table(runs$pace_tier)); cat("\n")

# 5. Modelling frame ---------------------------------------------------------
# IMPORTANT: exclude average_speed and max_speed.
# pace_tier is derived from average_speed, and max_speed correlates near-1
# with it -> using either would leak the target into the predictors.
model_df <- runs %>%
  select(pace_tier,
         distance, moving_time, elapsed_time,
         total_elevation_gain, athlete_count)

# 6. Train / test split ------------------------------------------------------
set.seed(123)
idx       <- createDataPartition(model_df$pace_tier, p = 0.7, list = FALSE)
train_set <- model_df[idx, ]
test_set  <- model_df[-idx, ]

cat("Train rows:", nrow(train_set), "  Test rows:", nrow(test_set), "\n")
cat("Train tier counts:\n"); print(table(train_set$pace_tier))
cat("Test  tier counts:\n"); print(table(test_set$pace_tier));  cat("\n")

# 7. Center + scale numeric predictors (kNN is distance-based) ---------------
num_cols <- c("distance", "moving_time", "elapsed_time",
              "total_elevation_gain", "athlete_count")
preProc  <- preProcess(train_set[, num_cols], method = c("center", "scale"))
train_s  <- predict(preProc, train_set[, num_cols])
test_s   <- predict(preProc, test_set[, num_cols])

# 8. kNN with 10-fold CV over k = 1, 3, ..., 15 ------------------------------
ctrl <- trainControl(method = "cv", number = 10)
set.seed(123)
knn_tune <- train(
  x        = train_s,
  y        = train_set$pace_tier,
  method   = "knn",
  trControl = ctrl,
  tuneGrid = expand.grid(k = seq(1, 15, 2))
)

cat("\n========== kNN tuning ==========\n")
print(knn_tune)
cat("Best k:", knn_tune$bestTune$k, "\n\n")

# 9. kNN test-set evaluation -------------------------------------------------
knn_pred <- predict(knn_tune, test_s)
cat("========== kNN confusion matrix (test set) ==========\n")
knn_cm <- confusionMatrix(knn_pred, test_set$pace_tier)
print(knn_cm)

# 10. CART for comparison ----------------------------------------------------
set.seed(123)
cart_cls <- rpart(
  pace_tier ~ distance + moving_time + elapsed_time +
              total_elevation_gain + athlete_count,
  data   = train_set,
  method = "class"
)

cat("\n========== CART tree ==========\n")
print(cart_cls)
rpart.plot(cart_cls, type = 2, extra = 104,
           main = "CART: Pace-Tier Classification Tree")

cart_pred <- predict(cart_cls, test_set, type = "class")
cat("\n========== CART confusion matrix (test set) ==========\n")
cart_cm <- confusionMatrix(cart_pred, test_set$pace_tier)
print(cart_cm)

# 11. Side-by-side accuracy summary ------------------------------------------
acc_summary <- data.frame(
  model    = c("kNN", "CART"),
  accuracy = c(knn_cm$overall["Accuracy"], cart_cm$overall["Accuracy"]),
  kappa    = c(knn_cm$overall["Kappa"],    cart_cm$overall["Kappa"])
)
cat("\n========== Model comparison ==========\n")
print(acc_summary, row.names = FALSE)

# 12. Baseline sanity check (what does "always predict Medium" score?) ------
baseline_pred <- factor(rep("Medium", nrow(test_set)),
                        levels = levels(test_set$pace_tier))
baseline_acc  <- mean(baseline_pred == test_set$pace_tier)
cat(sprintf("\nNaive baseline (always 'Medium') accuracy: %.3f\n", baseline_acc))
cat("Both models should beat this to be considered useful.\n")
