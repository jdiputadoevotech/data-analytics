library(tidyverse)
setwd("C:/Users/Janritch/OneDrive/Documents/Rmarkdown")
strava <- read.csv("strava.csv")[c(4,5,6,7,10)]
dim(strava)
glimpse(strava)

library(caret)

strava <- strava %>% drop_na()

strava$sport_type <- factor(strava$sport_type)

# 5. Keep modelling variables only
# Predictors: cols 4,5,6,7 | Outcome: col 10 (sport_type)
model_df <- strava %>%
  select(distance, moving_time, elapsed_time,
         total_elevation_gain, sport_type)

dim(model_df)

set.seed(123)
idx       <- createDataPartition(model_df$sport_type, p = 0.7, list = FALSE)
train_set <- model_df[idx, ]
test_set  <- model_df[-idx, ]

cat("Train rows:", nrow(train_set), " Test rows:", nrow(test_set), "\n")


library(class)
num_cols <- c("distance","moving_time","elapsed_time",
              "total_elevation_gain")
preProc  <- preProcess(train_set[, num_cols], method = c("center","scale"))
train_s  <- predict(preProc, train_set[, num_cols])
test_s   <- predict(preProc, test_set[, num_cols])

ctrl <- trainControl(method = "cv", number = 10)
knn_tune <- train(x = train_s, y = train_set$sport_type,
                  method = "knn", trControl = ctrl,
                  tuneGrid = expand.grid(k = seq(1, 15, 2)))
knn_pred <- predict(knn_tune, test_s)
confusionMatrix(knn_pred, test_set$sport_type)

