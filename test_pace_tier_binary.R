# test_pace_tier_binary.R ---------------------------------------------------
# Binary pace classification: Slow (bottom tertile) vs Fast (top tertile).
# Drops the ambiguous Medium tier (middle tertile of average_speed).
# Rationale: middle-tertile runs sit at the bin boundary and are
# fundamentally ambiguous; removing them gives a cleaner decision problem.
# ---------------------------------------------------------------------------

needed <- c("tidyverse","caret","class","rpart","rpart.plot",
            "kknn","randomForest","MLmetrics","pROC")
inst   <- needed[!(needed %in% installed.packages()[,"Package"])]
if (length(inst)) install.packages(inst, repos = "https://cloud.r-project.org")
invisible(lapply(needed, library, character.only = TRUE))

# 1. Load + clean ------------------------------------------------------------
strava <- read.csv("strava.csv", stringsAsFactors = FALSE) %>%
  drop_na() %>%
  filter(distance > 0, elapsed_time < 30000)
strava$type <- factor(strava$type)
runs <- strava %>% filter(type == "Run")

# 2. Tertiles, then drop the middle -----------------------------------------
tert <- quantile(runs$average_speed, probs = c(0, 1/3, 2/3, 1))
runs$pace_tier <- cut(runs$average_speed, breaks = tert,
                     labels = c("Slow","Medium","Fast"), include.lowest = TRUE)

bin_df <- runs %>%
  filter(pace_tier %in% c("Slow","Fast")) %>%
  mutate(pace = factor(as.character(pace_tier), levels = c("Slow","Fast")))

cat("Binary class counts:\n"); print(table(bin_df$pace)); cat("\n")

# 3. Feature engineering -----------------------------------------------------
bin_df <- bin_df %>%
  mutate(
    log_distance    = log1p(distance),
    log_moving_time = log1p(moving_time),
    log_elevation   = log1p(total_elevation_gain),
    rest_ratio      = (elapsed_time - moving_time) / elapsed_time
  )

model_df <- bin_df %>%
  select(pace, log_distance, log_moving_time, log_elevation, rest_ratio)

# 4. Split -------------------------------------------------------------------
set.seed(123)
idx       <- createDataPartition(model_df$pace, p = 0.7, list = FALSE)
train_set <- model_df[idx, ]
test_set  <- model_df[-idx, ]
cat("Train:", nrow(train_set), " Test:", nrow(test_set), "\n")
cat("Train counts:\n"); print(table(train_set$pace))
cat("Test  counts:\n"); print(table(test_set$pace));  cat("\n")

# 5. Scale -------------------------------------------------------------------
num_cols <- setdiff(names(model_df), "pace")
preProc  <- preProcess(train_set[, num_cols], method = c("center","scale"))
train_s  <- predict(preProc, train_set[, num_cols]); train_s$pace <- train_set$pace
test_s   <- predict(preProc, test_set[,  num_cols]); test_s$pace  <- test_set$pace

ctrl <- trainControl(method = "repeatedcv", number = 10, repeats = 5,
                     classProbs = TRUE, summaryFunction = twoClassSummary)

# 6. Models ------------------------------------------------------------------
set.seed(123)
knn_fit <- train(pace ~ ., data = train_s, method = "knn",
                 trControl = ctrl, metric = "ROC",
                 tuneGrid = expand.grid(k = seq(1, 21, 2)))

set.seed(123)
kknn_fit <- train(pace ~ ., data = train_s, method = "kknn",
                  trControl = ctrl, metric = "ROC",
                  tuneGrid = expand.grid(
                    kmax     = seq(3, 21, 2),
                    distance = c(1, 2),
                    kernel   = c("rectangular","triangular","gaussian")))

set.seed(123)
cart_fit <- train(pace ~ ., data = train_s, method = "rpart",
                  trControl = ctrl, metric = "ROC",
                  tuneGrid = expand.grid(cp = seq(0, 0.2, 0.01)))

set.seed(123)
rf_fit <- train(pace ~ ., data = train_s, method = "rf",
                trControl = ctrl, metric = "ROC",
                tuneGrid = expand.grid(mtry = 1:4),
                ntree = 500)

set.seed(123)
glm_fit <- train(pace ~ ., data = train_s, method = "glm",
                 family = binomial(),
                 trControl = ctrl, metric = "ROC")

# 7. Test-set evaluation ----------------------------------------------------
eval_one <- function(fit, name) {
  pred  <- predict(fit, test_s)
  prob  <- predict(fit, test_s, type = "prob")[, "Fast"]
  cm    <- confusionMatrix(pred, test_s$pace, positive = "Fast")
  auc   <- as.numeric(pROC::roc(test_s$pace, prob, levels = c("Slow","Fast"),
                                direction = "<", quiet = TRUE)$auc)
  data.frame(
    model    = name,
    cv_roc   = max(fit$results$ROC, na.rm = TRUE),
    test_acc = unname(cm$overall["Accuracy"]),
    test_kap = unname(cm$overall["Kappa"]),
    test_sens = unname(cm$byClass["Sensitivity"]),
    test_spec = unname(cm$byClass["Specificity"]),
    test_auc = auc
  )
}

results <- bind_rows(
  eval_one(knn_fit,  "kNN (vanilla)"),
  eval_one(kknn_fit, "kNN (weighted)"),
  eval_one(cart_fit, "CART (tuned cp)"),
  eval_one(rf_fit,   "Random Forest"),
  eval_one(glm_fit,  "Logistic Regression")
)

cat("\n========== Best hyperparameters ==========\n")
cat("kNN  k =", knn_fit$bestTune$k, "\n")
cat("kknn :"); print(kknn_fit$bestTune)
cat("CART cp =", cart_fit$bestTune$cp, "\n")
cat("RF mtry =", rf_fit$bestTune$mtry, "\n")

cat("\n========== Model comparison ==========\n")
print(results, row.names = FALSE, digits = 3)

baseline_acc <- max(prop.table(table(test_s$pace)))
cat(sprintf("\nNaive majority-class baseline accuracy: %.3f\n", baseline_acc))

# 8. Best-model confusion matrix --------------------------------------------
best   <- results$model[which.max(results$test_acc)]
fit_lu <- list("kNN (vanilla)"=knn_fit, "kNN (weighted)"=kknn_fit,
               "CART (tuned cp)"=cart_fit, "Random Forest"=rf_fit,
               "Logistic Regression"=glm_fit)
cat(sprintf("\n========== Confusion matrix: %s ==========\n", best))
print(confusionMatrix(predict(fit_lu[[best]], test_s),
                      test_s$pace, positive = "Fast"))

# 9. Variable importance ----------------------------------------------------
cat("\n========== CART variable importance ==========\n"); print(varImp(cart_fit))
cat("\n========== RF variable importance ==========\n");   print(varImp(rf_fit))

# 10. Plot the best CART tree -----------------------------------------------
rpart.plot(cart_fit$finalModel, type = 2, extra = 104,
           main = "CART: Slow vs Fast Run Classification")
