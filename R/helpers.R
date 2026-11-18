# Functions shared by the Study 1 and Study 2 analyses.
#
# Every model is fitted with 4 chains of 4,000 iterations (2,000 warmup) and
# seed 42, and saved to MODEL_DIR. On later runs the saved model is loaded
# rather than refitted, after checking that its formula, family, priors,
# sampler settings and data are identical to those specified in the script.
# Any difference stops the script.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(brms)
  library(posterior)
})

N_CHAINS <- 4
N_ITER   <- 4000
N_WARMUP <- 2000
SEED     <- 42
LO <- 0.055   # 89% credible intervals
HI <- 0.945

MODEL_DIR <- Sys.getenv("MODEL_CACHE", unset = "model_cache")
dir.create(MODEL_DIR, showWarnings = FALSE, recursive = TRUE)

formula_text <- function(f) {
  if (!inherits(f, "brmsformula")) f <- bf(f)
  parts <- c(deparse1(f$formula), vapply(f$pforms, deparse1, character(1)))
  sort(gsub("\\s+", " ", parts))
}

prior_text <- function(p) {
  p <- as.data.frame(p)
  if ("source" %in% names(p)) p <- p[p$source == "user", ]
  # brms stores an LKJ prior on correlations as the equivalent prior on their
  # Cholesky factor.
  lkj <- p$class == "cor"
  p$prior[lkj] <- sub("^lkj\\(", "lkj_corr_cholesky(", p$prior[lkj])
  p$class[lkj] <- "L"
  sort(paste(p$prior, p$class, p$coef, p$group, p$dpar, sep = "|"))
}

same_values <- function(a, b) {
  if (is.factor(a)) a <- as.character(a)
  if (is.factor(b)) b <- as.character(b)
  isTRUE(all.equal(a, b, check.attributes = FALSE))
}

check_saved_model <- function(m, name, formula, data, prior, family, adapt_delta) {
  args <- m$fit@stan_args[[1]]
  sim  <- m$fit@sim
  new  <- as.data.frame(data)[, names(m$data), drop = FALSE]
  new  <- new[complete.cases(new), , drop = FALSE]
  ok <- c(
    formula = identical(formula_text(m$formula), formula_text(formula)),
    family  = identical(tolower(c(m$family$family, m$family$link)),
                        tolower(c(family$family, family$link))),
    priors  = identical(prior_text(m$prior), prior_text(prior)),
    sampler = sim$chains == N_CHAINS && sim$iter == N_ITER && sim$warmup == N_WARMUP &&
              args$seed == SEED && isTRUE(all.equal(args$control$adapt_delta, adapt_delta)),
    data    = nrow(new) == nrow(m$data) && all(mapply(same_values, new, m$data)))
  if (!all(ok))
    stop("Saved model '", name, "' differs from the script in: ",
         paste(names(ok)[!ok], collapse = ", "), ". Delete the file to refit it.")
  invisible(TRUE)
}

fit_or_load <- function(name, formula, data, prior, family, adapt_delta,
                        sample_prior = "no") {
  path <- file.path(MODEL_DIR, paste0(name, ".rds"))
  if (file.exists(path)) {
    m <- readRDS(path)
    if (!inherits(m, "brmsfit")) m <- m$fit
    check_saved_model(m, name, formula, data, prior, family, adapt_delta)
    return(m)
  }
  m <- brm(formula, data = data, prior = prior, family = family,
           chains = N_CHAINS, iter = N_ITER, warmup = N_WARMUP, seed = SEED,
           control = list(adapt_delta = adapt_delta), sample_prior = sample_prior,
           cores = min(N_CHAINS, parallel::detectCores()), silent = 2, refresh = 0)
  saveRDS(m, path)
  m
}

# Refit an existing model to a subset of its data, reusing the compiled model.
refit_on <- function(name, model, newdata) {
  adapt_delta <- model$fit@stan_args[[1]]$control$adapt_delta
  path <- file.path(MODEL_DIR, paste0(name, ".rds"))
  if (file.exists(path)) {
    m <- readRDS(path)
    check_saved_model(m, name, model$formula, newdata, model$prior, model$family, adapt_delta)
    return(m)
  }
  m <- update(model, newdata = newdata, recompile = FALSE,
              chains = N_CHAINS, iter = N_ITER, warmup = N_WARMUP, seed = SEED,
              control = list(adapt_delta = adapt_delta),
              cores = min(N_CHAINS, parallel::detectCores()), silent = 2, refresh = 0)
  saveRDS(m, path)
  m
}

# Posterior mean, 89% credible interval and P(> 0) of a vector of draws.
summ <- function(x, label = "") {
  data.frame(term = label, estimate = mean(x),
             lower = quantile(x, LO, names = FALSE),
             upper = quantile(x, HI, names = FALSE),
             p_positive = mean(x > 0))
}

# Convergence diagnostics, as reported in Table S9: largest R-hat over all
# parameters, smallest bulk ESS over the fixed effects and over all parameters,
# smallest tail ESS, and the number of divergent transitions.
convergence <- function(m, label) {
  s  <- summarise_draws(as_draws_df(m), "rhat", "ess_bulk", "ess_tail")
  s  <- s[!s$variable %in% c("lp__", "lprior"), ]
  fe <- s[grepl("^b_", s$variable), ]
  np <- nuts_params(m)
  data.frame(model = label, N = nobs(m),
             max_rhat = max(s$rhat, na.rm = TRUE),
             bulk_ess_fixed = min(fe$ess_bulk),
             bulk_ess_all = min(s$ess_bulk, na.rm = TRUE),
             tail_ess_all = min(s$ess_tail, na.rm = TRUE),
             divergences = sum(np$Value[np$Parameter == "divergent__"]))
}
