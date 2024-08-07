# Are tests failing here?
# UPDATE THE FIXTURES!
# make update-test-fixtures

library(testthat)
library(caret)

data(models.reg)
data(X.reg)
data(Y.reg)

data(models.class)
data(X.class)
data(Y.class)

#############################################################################
context("Test errors and warnings")
#############################################################################
test_that("Ensembling fails with no CV", {
  my_control <- trainControl(method = "none", savePredictions = "final")
  expect_error(suppressWarnings(trControlCheck(my_control)))
})

#############################################################################
context("Test metric and residual extraction")
#############################################################################

test_that("We can extract metrics", {
  data(iris)
  mod <- train(
    iris[, 1:2], iris[, 3],
    method = "lm",
    trControl = trainControl(
      method = "cv", number = 3, savePredictions = "final"
    )
  )
  m1 <- getMetric(mod, "RMSE")
  m2 <- getMetric.train(mod, "RMSE")
  expect_equal(m1, m2)

  m1 <- getMetricSD(mod, "RMSE")
  m2 <- getMetricSD.train(mod, "RMSE")
  expect_equal(m1, m2)
})

test_that("We can extract resdiuals from caretEnsemble objects", {
  ens <- caretEnsemble(models.class)
  suppressWarnings(r <- residuals(ens))
  expect_is(r, "numeric")
  expect_equal(length(r), 150)

  ens <- caretEnsemble(models.reg)
  suppressWarnings(r <- residuals(ens))
  expect_is(r, "numeric")
  expect_equal(length(r), 150)
})

test_that("We can extract resdiuals from train regression objects", {
  data(iris)
  mod <- train(
    iris[, 1:2], iris[, 3],
    method = "lm",
    trControl = trainControl(
      method = "cv", number = 3, savePredictions = "final"
    )
  )
  r <- residuals(mod)
  expect_is(r, "numeric")
  expect_equal(length(r), 150)
})

#############################################################################
context("Does ensembling and prediction work?")
#############################################################################

test_that("We can ensemble regression models", {
  ens.reg <- caretEnsemble(models.reg, trControl = trainControl(number = 2))
  expect_that(ens.reg, is_a("caretEnsemble"))
  suppressWarnings(pred.reg <- predict(ens.reg))
  suppressWarnings(pred.reg2 <- predict(ens.reg, se = TRUE))

  expect_true(all(pred.reg == pred.reg2$fit))

  suppressWarnings(expect_error(predict(ens.reg, return_weights = "BOGUS")))

  expect_true(is.numeric(pred.reg))
  expect_true(length(pred.reg) == 150)
  ens.class <- caretEnsemble(models.class, trControl = trainControl(number = 2))
  expect_that(ens.class, is_a("caretEnsemble"))
  suppressWarnings(pred.class <- predict(ens.class, type = "prob"))
  expect_true(is.numeric(pred.class))
  expect_true(length(pred.class) == 150)

  # Check different cases
  suppressWarnings(p1 <- predict(ens.reg, return_weights = TRUE, se = FALSE))
  expect_is(attr(p1, which = "weights"), "numeric")
  expect_is(p1, "numeric")

  suppressWarnings(p2 <- predict(ens.reg, return_weights = TRUE, se = TRUE))
  expect_is(attr(p2, which = "weights"), "numeric")
  expect_is(p2, "data.frame")
  expect_equal(ncol(p2), 3)
  expect_identical(names(p2), c("fit", "lwr", "upr"))

  suppressWarnings(p3 <- predict(ens.reg, return_weights = FALSE, se = FALSE))
  expect_is(p3, "numeric")
  expect_true(all(p1 == p3))
  expect_false(identical(p1, p3))

  expect_true(all(p2$fit == p1))
  expect_true(all(p2$fit == p3))
  expect_null(attr(p3, which = "weights"))
})

#############################################################################
context("Does ensembling work with models with differing predictors")
#############################################################################

test_that("We can ensemble models of different predictors", {
  skip_on_cran()
  data(iris)
  Y.reg <- iris[, 1]
  X.reg <- model.matrix(~., iris[, -1])
  mseeds <- vector(mode = "list", length = 12)
  myControl <- trainControl(
    method = "cv", number = 10,
    p = 0.75, savePrediction = TRUE,
    classProbs = FALSE, returnResamp = "final",
    returnData = TRUE
  )

  set.seed(482)
  glm1 <- train(x = X.reg[, c(-1, -2, -6)], y = Y.reg, method = "glm", trControl = myControl)
  set.seed(482)
  glm2 <- train(x = X.reg[, c(-1, -3, -6)], y = Y.reg, method = "glm", trControl = myControl)
  set.seed(482)
  glm3 <- train(x = X.reg[, c(-1, -2, -3, -6)], y = Y.reg, method = "glm", trControl = myControl)
  set.seed(482)
  glm4 <- train(x = X.reg[, c(-1, -4, -6)], y = Y.reg, method = "glm", trControl = myControl)

  nestedList <- list(glm1, glm2, glm3, glm4)
  class(nestedList) <- "caretList"
  ensNest <- caretEnsemble(nestedList, trControl = trainControl(number = 2))
  expect_is(ensNest, "caretEnsemble")
  pred.nest <- predict(ensNest, newdata = X.reg)
  expect_true(is.numeric(pred.nest))
  expect_true(length(pred.nest) == 150)

  X_reg_new <- X.reg
  X_reg_new[2, 3] <- NA
  X_reg_new[25, 3] <- NA
  p_with_nas <- predict(ensNest, newdata = X_reg_new)
})

context("Does ensemble prediction work with new data")

test_that("It works for regression models", {
  set.seed(1234)
  ens.reg <- caretEnsemble(models.reg, trControl = trainControl(number = 2))
  expect_is(ens.reg, "caretEnsemble")
  suppressWarnings(pred.reg <- predict(ens.reg))
  newPreds1 <- as.data.frame(X.reg)
  suppressWarnings(pred.regb <- predict(ens.reg, newdata = newPreds1))
  suppressWarnings(pred.regc <- predict(ens.reg, newdata = newPreds1[2, ]))
  expect_identical(pred.reg, pred.regb)
  expect_lt(abs(4.712746 - pred.regc), 0.01)
  expect_is(pred.reg, "numeric")
  expect_is(pred.regb, "numeric")
  expect_is(pred.regc, "numeric")
  expect_equal(length(pred.regc), 1)
})

test_that("It works for classification models", {
  set.seed(1234)
  ens.class <- caretEnsemble(models.class, trControl = trainControl(number = 2))
  expect_that(ens.class, is_a("caretEnsemble"))
  suppressWarnings(pred.class <- predict(ens.class, type = "prob"))
  newPreds1 <- as.data.frame(X.class)
  suppressWarnings(pred.classb <- predict(ens.class, newdata = newPreds1, type = "prob"))
  suppressWarnings(pred.classc <- predict(ens.class, newdata = newPreds1[2, ], type = "prob"))
  expect_true(is.numeric(pred.class))
  expect_true(length(pred.class) == 150)
  expect_identical(pred.class, pred.classb)
  expect_lt(abs(0.9633519 - pred.classc), 0.01)
  expect_is(pred.class, "numeric")
  expect_is(pred.classb, "numeric")
  expect_is(pred.classc, "numeric")
  expect_equal(length(pred.classc), 1)
})

context("Do ensembles of custom models work?")

test_that("Ensembles using custom models work correctly", {
  set.seed(1234)

  # Create custom caret models with a properly assigned method attribute
  custom.rf <- getModelInfo("rf", regex = FALSE)[[1]]
  custom.rf$method <- "custom.rf"

  custom.rpart <- getModelInfo("rpart", regex = FALSE)[[1]]
  custom.rpart$method <- "custom.rpart"

  # Define models to be used in ensemble
  tune.list <- list(
    # Add an unnamed model to ensure that method names are extracted from model info
    caretModelSpec(method = custom.rf, tuneLength = 1),
    # Add a named custom model, to contrast the above
    myrpart = caretModelSpec(method = custom.rpart, tuneLength = 1),
    # Add a non-custom model
    treebag = caretModelSpec(method = "treebag", tuneLength = 1)
  )
  train.control <- trainControl(method = "cv", number = 2, classProbs = TRUE)
  X.df <- as.data.frame(X.class)

  # Create an ensemble using the above models
  suppressWarnings(cl <- caretList(X.df, Y.class, tuneList = tune.list, trControl = train.control))
  expect_that(cl, is_a("caretList"))
  expect_silent(cs <- caretEnsemble(cl))
  expect_that(cs, is_a("caretEnsemble"))

  # Validate names assigned to ensembled models
  expect_equal(sort(names(cs$models)), c("custom.rf", "myrpart", "treebag"))

  # Validate ensemble predictions
  suppressWarnings(pred.classa <- predict(cs, type = "prob"))
  expect_silent(pred.classb <- predict(cs, newdata = X.df, type = "prob"))
  expect_silent(pred.classc <- predict(cs, newdata = X.df[2, ], type = "prob"))
  expect_true(is.numeric(pred.classa))
  expect_true(is.numeric(pred.classb))
  expect_true(is.numeric(pred.classc))
  expect_true(length(pred.classa) == 150)
  expect_true(length(pred.classb) == 150)
  expect_true(length(pred.classc) == 1)
  expect_identical(pred.classa, pred.classb)
  expect_lt(abs(0.9749462 - pred.classc), 0.05)

  # Verify that not specifying a method attribute for custom models causes an error
  tune.list <- list(
    # Add a custom caret model WITHOUT a properly assigned method attribute
    caretModelSpec(method = getModelInfo("rf", regex = FALSE)[[1]], tuneLength = 1),
    treebag = caretModelSpec(method = "treebag", tuneLength = 1)
  )
  msg <- "Custom models must be defined with a \"method\" attribute"
  expect_error(caretList(X.class, Y.class, tuneList = tune.list, trControl = train.control), regexp = msg)
})


#############################################################################
context("Other tests to get to 100% coverage")
#############################################################################

test_that("fortify stops for unknown model type", {
  mock_model <- list(
    ens_model = list(modelType = "Unknown"),
    models = list(list(trainingData = data.frame(.outcome = 1:10)))
  )
  class(mock_model) <- "caretEnsemble"
  expect_error(fortify(mock_model), "Uknown model type Unknown")
})
