# pointing
# Analysis Code for Breeze, Lu, Levan, Lillo-Martin, & Goldin-Meadow

**Children can override the gestural models they see to create a linguistic system**

Submitted to *Science*

[![DOI](https://zenodo.org/badge/1216365234.svg)](https://doi.org/10.5281/zenodo.19672491)

## Overview

This repository contains all R code used for the statistical analyses and visualisations reported in the manuscript. The study compares the duration of pointing gestures in three groups of children (English-learners, ASL-learners, and homesigners) to test whether deaf children who create their own gestural communication systems produce points that resemble the co-speech gestures they see or the sign-language points they have never seen.

## Data availability

Individual-level coded data (pointing durations, semantic role classifications, utterance types) cannot be shared publicly because the institutional review board protocols under which the data were originally collected do not permit release of individual participant data without a data use agreement. These protocols predate current open data requirements and cannot be amended retroactively. Researchers seeking access to the data for purposes of reproducing or extending the analyses should contact the corresponding author (sgm@uchicago.edu) to initiate a data use agreement with the University of Chicago.

Summary statistics for all analyses are reported in the manuscript and supplementary materials.

## Repository structure

```
├── README.md
├── data_visualizations.Rmd        # Descriptive statistics, summary tables, 
│                                    and all figures (Figs. 1–3, S1–S3)
├── duration_bayesian_analysis.Rmd  # All Bayesian models and sensitivity analyses
└── session_info.txt               # Output of sessionInfo() for reproducibility
```

## Script descriptions

### `data_visualizations.Rmd`

Data cleaning, preparation, and all visualisations reported in the manuscript.

- **Section 1** – Setup and data loading (reads three CSV files: hearing, homesign, deaf)
- **Section 2** – Data cleaning and standardisation across datasets, including age-bin harmonisation, utterance type classification, and merging into a single combined dataframe
- **Section 3** – Descriptive statistics and visualisations:
  - Data presence tables for ASL-learners and homesigners
  - Table 1: Number of children observed and points produced at each age
  - Redundancy analysis of pointing gestures in hearing children
  - Multi-word/multi-sign utterance proportions by group
  - Mixed-effects logistic regression (via `lme4::glmer`) testing whether semantic category usage differs by language group
  - Semantic role distributions (Visualisations 4a–4g): counts and proportions across language groups
  - Duration density plots: overall (Fig. 2), isolated points (Fig. 3), developmental trajectories by age, and individual-level plots for ASL-learners and homesigners (supplementary figures)
  - Duration by semantic category (entity vs. other) faceted plots

### `duration_bayesian_analysis.Rmd`

All Bayesian statistical models reported in the manuscript, with full diagnostics.

- **Sections 1–3** – Setup, data loading, cleaning (mirrors the visualisation script). Defines helper functions: `fit_or_load()` (model caching), `check_diagnostics()`, `summarise_group_means()`, `summarise_contrasts()`, `posterior_plot()`, `check_loo_pareto()`
- **Section 4** – Data integrity checks: non-positive durations, sample sizes, skewness justifying log-transform
- **Section 5** – Prior specification and justification:
  - Intercept: Normal(0, 1) — 95% prior mass on 0.14 s to 7.4 s
  - Fixed effects (b): Normal(0, 0.5) — 95% prior mass on 0.37x to 2.7x multiplicative difference
  - Random effect SDs: Exponential(1)
  - Residual SD (sigma): Exponential(1)
- **Section 6** – Main analysis (all points, N = 2,428: 511 English-learners, 1,126 ASL-learners, 791 homesigners):
  - Prior predictive check
  - Bayesian log-linear mixed-effects model: `log_duration ~ language_group + (1 | subject) + (1 | age_numeric)`, Gaussian family, 4 chains × 4,000 iterations (2,000 warmup), adapt_delta = 0.95
  - Gamma GLMM alternative: `duration_sec ~ language_group + (1 | subject) + (1 | age_numeric)`, Gamma(link = "log") family
  - MCMC diagnostics (R-hat, Bulk ESS, Tail ESS, divergent transitions, trace plots)
  - Posterior predictive checks
  - Back-transformed marginal means (geometric means in seconds) with 89% credible intervals
  - Pairwise contrasts with posterior probabilities
  - LOO-CV model comparison (null vs. full)
  - Jacobian-corrected LOO comparison of log-normal vs. Gamma distributional assumptions
- **Section 7** – Isolated-points analysis (point_alone subset, N = 1,044: 186 English-learners, 456 ASL-learners, 402 homesigners):
  - Same model structure but with participant as the only random intercept (age random effect excluded because it could not be reliably estimated from this smaller dataset)
  - ROPE analysis for ASL vs. homesigner equivalence (±0.10 and ±0.20 log-units)
- **Sections 8A–8C** – Semantic controls for all points (N = 2,200, excluding unclear): full nine-category, entity-vs.-other, and action-vs.-static covariates
- **Sections 9A–9C** – Semantic controls for isolated points (N = 941, excluding unclear): same three covariates, no age random effect
- **Sections 10A–10C** – Semantic controls for points-not-alone (N = 1,234, excluding unclear): same three covariates
- **Section 11** – Sensitivity analyses:
  - Wide priors: Normal(0, 1) for fixed effects, Exponential(0.5) for SDs and sigma
  - Narrow subject-SD prior: Exponential(2) to test robustness with N = 3 subjects per deaf group
  - Subject-level variance posterior vs. prior comparison

All models use `seed = 42` for reproducibility and are cached to disk via `fit_or_load()` to avoid unnecessary refitting on subsequent runs.

## Expected input data

The scripts expect three CSV files (not included; see Data availability above). A researcher who obtains the data via a data use agreement should expect the following structure:

**Hearing children dataset** (`all_hearing_August_2025_final.csv`):
- `subject` – participant ID
- `age` – age in months (18, 22, 26, 30, 34)
- `utt_type` – utterance type (e.g., `point_alone`, `point+singleword`, `point_in_multiword_utt`, `point+singleword_pron`, `point+pronoun_in_multiword_utt`, `point+pronoun_only`)
- `modality` – `Points` or `Pronouns`
- `duration_sec` – pointing duration in seconds
- `semantic_cat` – semantic role of referent (actor, patient, instrument, source, recipient, place, entity, location, possessor)
- `c_utts` – child utterance transcription
- `pt_redundancy` – redundancy classification (Point Alone, Not Redundant, Redundant with Pronoun, Redundant with Other PoS, unclear)

**Deaf children / ASL dataset** (`PointCodingExportFINAL_022426.csv`):
- `subject` – participant ID 
- `age` – age in years;months format (e.g., `1;06`)
- `utterance_type` – utterance context (e.g., `Alone`, `Multi-sign_utterance`)
- `duration_sec` – pointing duration in seconds
- `semantic_category` – semantic role of referent 
- `number_of_signs` – number of signs in the utterance 

**Homesign children dataset** (`homesign_points2.csv`):
- `Subject` – participant ID 
- `Age` – age in years;months format
- `Utterance_type` – `Alone` or `Multi-gesture utterance`
- `Duration...ss.msec` – pointing duration in seconds
- `semantic_cat` – semantic role of referent
- `Number.of.signs` – number of gestures in the utterance

Note: Column names are case-sensitive and differ across datasets (e.g., `subject` vs. `Subject`, `age` vs. `Age`). The scripts handle this during the merging step.

## Requirements

### R version

Developed and tested on R 4.5.2 (2025-10-31), platform aarch64-apple-darwin20 (macOS Sonoma 14.4.1). See `session_info.txt` for full details.

### Required packages

Packages directly loaded via `library()`:

| Package | Version used | Purpose |
|---------|-------------|---------|
| `brms` | 2.23.0 | Bayesian mixed-effects models (interfaces Stan/rstan 2.32.7) |
| `emmeans` | 2.0.2 | Marginal means and pairwise contrasts |
| `bayesplot` | 1.15.0 | MCMC trace plots, posterior predictive checks |
| `tidybayes` | 3.0.7 | Tidy extraction of posterior draws |
| `bayestestR` | 0.17.0 | ROPE analysis |
| `ggplot2` | 4.0.2 | All visualisations |
| `dplyr` | 1.2.0 | Data manipulation |
| `tidyr` | 1.3.2 | Data reshaping |
| `stringr` | 1.6.0 | String operations |
| `moments` | 0.14.1 | Skewness/kurtosis for data integrity checks |
| `kableExtra` | 1.4.0 | Formatted tables in R Markdown output |
| `Rcpp` | 1.1.1 | C++ interface (required by brms/rstan) |

Key packages loaded via namespace (installed automatically as dependencies):

| Package | Version used | Purpose |
|---------|-------------|---------|
| `rstan` | 2.32.7 | Stan interface for MCMC sampling |
| `loo` | 2.9.0 | LOO-CV model comparison |
| `lme4` | 2.0-1 | Frequentist mixed models (`glmer` used in semantic logistic regression) |
| `posterior` | 1.6.1 | Posterior draws manipulation |
| `knitr` | 1.51 | R Markdown rendering |

A Stan C++ toolchain is also required for `brms` to compile models (Rtools on Windows, Xcode command line tools on macOS).

Install all directly loaded packages:
```r
install.packages(c("brms", "emmeans", "bayesplot", "tidybayes", "bayestestR",
                    "ggplot2", "dplyr", "tidyr", "stringr", "moments",
                    "kableExtra"))
```

Note: Installing `brms` will automatically install `rstan`, `loo`, `lme4`, and other dependencies listed above.

## Running the analyses

1. Update the file paths at the top of each `.Rmd` to point to your local copies of the data files. In both scripts, these appear in the data loading sections as `read.csv()` calls pointing to `~/Library/CloudStorage/Box-Box/Pointing project 2025/datasets/...`.
2. In `duration_bayesian_analysis.Rmd`, update `MODEL_DIR` (Section 1) to a local directory where fitted model objects will be cached.
3. Knit `data_visualizations.Rmd` first to generate all figures and descriptive tables.
4. Knit `duration_bayesian_analysis.Rmd` to run all Bayesian models. On first run, models will be fitted and cached to disk. Subsequent runs load from cache automatically.

## Correspondence between code and manuscript

| Manuscript section | Code location |
|---|---|
| Table 1 (points by group and age) | `data_visualizations.Rmd`, Section 3 (summary table block) |
| Figure 1 (semantic role distributions) | `data_visualizations.Rmd`, Visualisation 4g (plot4g) |
| Figure 2 (overall duration densities) | `data_visualizations.Rmd`, plot5a_overall |
| Figure 3 (isolated-point durations) | `data_visualizations.Rmd`, plot6 |
| Main duration analysis (all points) | `duration_bayesian_analysis.Rmd`, Section 6 |
| Isolated-points analysis | `duration_bayesian_analysis.Rmd`, Section 7 |
| ROPE analysis (ASL vs. homesigner equivalence) | `duration_bayesian_analysis.Rmd`, Section 7 |
| Semantic control models (all points) | `duration_bayesian_analysis.Rmd`, Sections 8A–8C |
| Semantic control models (isolated) | `duration_bayesian_analysis.Rmd`, Sections 9A–9C |
| Semantic control models (not alone) | `duration_bayesian_analysis.Rmd`, Sections 10A–10C |
| Prior sensitivity analysis | `duration_bayesian_analysis.Rmd`, Section 11 |

## License

MIT License

## Contact

Corresponding author: Susan Goldin-Meadow (sgm@uchicago.edu)  
Department of Psychology, University of Chicago
