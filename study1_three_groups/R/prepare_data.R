# Study 1 data preparation, shared by study1_descriptives_and_figures.Rmd and
# study1_duration_models.Rmd.
#
# Input (data/):
#   all_hearing_August_2025_final.csv   English-learners: points and pronouns
#   PointCodingExportFINAL_022426.csv   ASL-learners: points
#   homesign_points2.csv                homesigners: points
#
# Output: combined_df (one row per coded point or pronoun) and the analysis
# datasets used by the models.

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
})

english_raw  <- read.csv("data/all_hearing_August_2025_final.csv", stringsAsFactors = FALSE)
asl_raw      <- read.csv("data/PointCodingExportFINAL_022426.csv", stringsAsFactors = FALSE)
homesign_raw <- read.csv("data/homesign_points2.csv", stringsAsFactors = FALSE)

# English-learners were recorded at 18, 22, 26, 30 and 34 months. ASL-learners
# and homesigners were visited at some point within each four-month interval;
# their ages are assigned to the nearest interval.
age_from_months <- function(m) case_when(
  m == 18 ~ "1;06", m == 22 ~ "1;10", m == 26 ~ "2;02", m == 30 ~ "2;06",
  m == 34 ~ "2;10", TRUE ~ as.character(m))

homesign_age_bin <- function(age) case_when(
  age == "2;05" ~ "2;02", age == "3;00" ~ "2;10", age == "3;03" ~ "3;02",
  age == "3;05" ~ "3;02", age == "3;09" ~ "3;06", age == "3;11" ~ "3;10",
  age == "4;00" ~ "3;10", age == "4;03" ~ "4;02", TRUE ~ age)

age_in_months <- function(age) case_when(
  age == "1;06" ~ 18, age == "1;10" ~ 22, age == "2;02" ~ 26, age == "2;06" ~ 30,
  age == "2;10" ~ 34, age == "3;02" ~ 38, age == "3;10" ~ 46, TRUE ~ NA_real_)

# n_elements: number of words, signs or gestures in the utterance, counting the
# point (used only for Figure S4).
english <- english_raw %>%
  mutate(age = age_from_months(as.numeric(as.character(age)))) %>%
  filter(!grepl("exclude", comments, ignore.case = TRUE)) %>%
  transmute(subject = as.character(subject), age, utt_type, modality, duration_sec,
            semantic_cat, language = "English",
            n_elements = if_else(is.na(c_utts) | str_squish(c_utts) == "", 0L,
                                 str_count(c_utts, "\\S+")) + 1L)

asl <- asl_raw %>%
  mutate(duration_sec = as.numeric(duration_sec),
         age = if_else(age %in% c("1;07", "1;06"), "1;06", age),
         semantic_category = if_else(semantic_category == "entity.location", "entity",
                                     semantic_category)) %>%
  filter(!is.na(duration_sec)) %>%
  transmute(subject = as.character(subject), age, utt_type = utterance_type,
            modality = "Points", duration_sec, semantic_cat = semantic_category,
            language = "ASL",
            n_elements = if_else(is.na(number_of_signs), 1L, as.integer(number_of_signs)))

homesign <- homesign_raw %>%
  mutate(Utterance_type = if_else(Utterance_type == "Alone ", "Alone", Utterance_type)) %>%
  filter(Subject != "") %>%
  transmute(subject = Subject, age = homesign_age_bin(Age), utt_type = Utterance_type,
            modality = "Points", duration_sec = Duration...ss.msec, semantic_cat,
            language = "Homesign",
            n_elements = case_when(!is.na(Number.of.signs) ~ as.integer(Number.of.signs),
                                   Utterance_type == "Alone" ~ 1L,
                                   TRUE ~ NA_integer_))

# English sessions outside 18-34 months keep their age in months; convert to
# years;months.
months_to_age <- function(x) {
  m <- suppressWarnings(as.numeric(x))
  paste(floor(m / 12), sprintf("%02d", m %% 12), sep = ";")
}
combined_df <- bind_rows(english, asl, homesign) %>%
  mutate(age = if_else(grepl("^\\d+$", age), months_to_age(age), age),
         utt_type = if_else(utt_type %in% c("point", "Alone"), "point_alone", utt_type))

groups <- c("English-Points", "ASL", "Homesign")
group_of <- function(language) factor(case_when(
  language == "English" ~ "English-Points",
  language == "ASL" ~ "ASL",
  language == "Homesign" ~ "Homesign"), levels = groups)

# Semantic covariates. Points whose referent could not be classified (unclear)
# are excluded from the models that control for semantic role. The binary
# covariates are defined for the nine semantic roles only, so points coded
# "other" enter the nine-role models but not the binary ones.
action_roles <- c("actor", "instrument", "patient", "recipient", "source")
static_roles <- c("entity", "location", "place", "possessor")
add_semantic <- function(d) {
  d %>%
    filter(!is.na(semantic_cat), semantic_cat != "unclear") %>%
    mutate(semantic_cat = factor(semantic_cat),
           entity_vs_other = factor(case_when(
             semantic_cat == "entity" ~ "entity",
             semantic_cat %in% c(action_roles, setdiff(static_roles, "entity")) ~ "other")),
           action_vs_static = factor(case_when(
             semantic_cat %in% action_roles ~ "ACTION",
             semantic_cat %in% static_roles ~ "STATIC")))
}

points_with_duration <- combined_df %>%
  filter(modality == "Points", !is.na(duration_sec), duration_sec > 0) %>%
  mutate(language_group = group_of(language),
         age_numeric = age_in_months(age),
         subject = factor(subject),
         log_duration = log(duration_sec))

# All points (Figure 2, Table S3)
all_points <- points_with_duration

# Points produced alone (Figure 3, Table S3)
isolated_points <- points_with_duration %>% filter(utt_type %in% "point_alone")

# Points produced with other words, signs or gestures (Table S3). Points whose
# context was coded as unclear are kept here; points with no context code are not.
with_other_points <- points_with_duration %>%
  filter(!is.na(utt_type), utt_type != "point_alone")

# Isolation-by-group model (Table S4): every point with a context code.
iso_by_group_points <- points_with_duration %>%
  filter(!is.na(utt_type)) %>%
  mutate(isolated = factor(if_else(utt_type == "point_alone", "Isolated", "Not Alone"),
                           levels = c("Not Alone", "Isolated")))

sem_all      <- add_semantic(all_points)
sem_isolated <- add_semantic(isolated_points)
sem_with     <- add_semantic(with_other_points)
binary_subset <- function(d, covariate) d[!is.na(d[[covariate]]), ]

# Figure S4: points produced with other acts, by the number of elements in the
# string (2, 3, 4, 5 or more).
by_length <- sem_with %>%
  filter(!is.na(n_elements), n_elements >= 2) %>%
  mutate(group = factor(recode(as.character(language_group), "English-Points" = "English"),
                        levels = c("English", "ASL", "Homesign")),
         len_bin = factor(if_else(n_elements >= 5, "L5", paste0("L", n_elements)),
                          levels = c("L2", "L3", "L4", "L5")))
