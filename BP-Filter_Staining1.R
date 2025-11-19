# ===== ONE-PLOT (tous CSV/XLSX du dossier) — deux plots séparés, filtré 0–5, ordre Neg/15/30/45/60/90/180 =====
library(tidyverse)
library(readxl)

choose_input_dir <- function(default = "/Users/tom/Downloads/Fiji_Results/Staining1") {
  def <- path.expand(default)
  if (interactive() && requireNamespace("tcltk", quietly = TRUE)) {
    p <- try(tcltk::tk_choose.dir(default = def, caption = "Choisis le dossier"), silent = TRUE)
    if (!inherits(p, "try-error") && !is.na(p) && nzchar(p)) return(p)
  }
  message("Pas de sélecteur : utilisation de ", def)
  def
}
input_dir <- choose_input_dir()
stopifnot(dir.exists(input_dir))

# ---------- Lecture des fichiers ----------
files_csv  <- list.files(input_dir, pattern = "\\.csv$",        full.names = TRUE, ignore.case = TRUE)
files_xlsx <- list.files(input_dir, pattern = "\\.(xlsx|xls)$", full.names = TRUE, ignore.case = TRUE)
files <- c(files_csv, files_xlsx)
if (!length(files)) stop("Aucun CSV/XLSX trouvé dans : ", input_dir)

# ---------- Lecture + normalisation ----------
read_any <- function(f) {
  ext <- tolower(tools::file_ext(f))
  df <- tryCatch(
    if (ext %in% c("xlsx","xls")) read_excel(f) else readr::read_csv(f, show_col_types = FALSE),
    error = function(e) { message(">> Skip (lecture échouée): ", basename(f), " — ", e$message); return(NULL) }
  )
  if (is.null(df) || !nrow(df)) { message(">> Skip (vide): ", basename(f)); return(NULL) }
  
  names(df) <- gsub("\\s+", "_", names(df))
  needed <- c("Mean_Green","Mean_Red","Mean_DAPI")
  if (!all(needed %in% names(df))) { message(">> Skip (colonnes manquantes) : ", basename(f)); return(NULL) }
  
  if (!"Condition" %in% names(df)) df$Condition <- "All"
  if (!"ROI_Index" %in% names(df)) df$ROI_Index <- seq_len(nrow(df))
  
  num_cols <- intersect(c("Mean_Green","Mean_Red","Mean_DAPI",
                          "IntDen_Green","IntDen_Red","IntDen_DAPI"), names(df))
  df <- df %>% mutate(across(all_of(num_cols), ~ suppressWarnings(as.numeric(.))))
  
  df %>%
    mutate(
      PolII_Ser5 = Mean_Green / Mean_DAPI,     # vert
      V5_TBP1    = Mean_Red   / Mean_DAPI,     # rouge
      SourceFile = tools::file_path_sans_ext(basename(f))
    ) %>%
    filter(is.finite(PolII_Ser5), is.finite(V5_TBP1))
}

all_dat <- purrr::map(files, read_any) %>% purrr::compact() %>% list_rbind()
if (!nrow(all_dat)) stop("Aucune ligne exploitable après lecture. Vérifie les colonnes.")

# ---------- Passage en long + filtre 0–5 ----------
dat_long <- all_dat %>%
  select(SourceFile, Condition, ROI_Index, PolII_Ser5, V5_TBP1) %>%
  pivot_longer(c(PolII_Ser5, V5_TBP1), names_to = "Channel", values_to = "Norm")

dat_long <- dat_long %>% filter(between(Norm, 0, 5))

# ---------- Parsing du time depuis le nom de fichier ----------
# On récupère un time en minutes à partir de SourceFile (neg, 15min, 3hrs -> 180, etc.)
order_levels <- c("0","15","30","45","60","90","180")

dat_long <- dat_long %>%
  mutate(
    lower = tolower(SourceFile),
    time_min = case_when(
      str_detect(lower, "neg")                 ~ -1,                                  # Neg
      str_detect(lower, "(\\d+)\\s*min")       ~ as.numeric(stringr::str_match(lower, "(\\d+)\\s*min")[,2]),
      str_detect(lower, "(\\d+)\\s*hr")        ~ 60 * as.numeric(stringr::str_match(lower, "(\\d+)\\s*hr")[,2]),
      str_detect(lower, "[-_]?0(min)?\\b")     ~ 0,                                    # 0 ou 0min
      TRUE                                     ~ NA_real_
    ),
    Time = case_when(
      is.na(time_min)        ~ NA_character_,
      time_min < 0           ~ "Neg",
      TRUE                   ~ as.character(as.integer(time_min))
    )
  ) %>%
  filter(Time %in% order_levels) %>%                                # ne garder que les time demandés
  mutate(
    Time    = factor(Time, levels = order_levels, ordered = TRUE),
    Channel = factor(Channel, levels = c("PolII_Ser5","V5_TBP1"),
                     labels = c("PolII_Ser5","V5-TBP1"))
  )

# Couleurs & style
col_polii <- "green"
col_v5    <- "red"

# ---------- Plot 1 : PolII_Ser5 ----------
df_pol <- dat_long %>% filter(Channel == "PolII_Ser5")
p_pol <- ggplot(df_pol, aes(x = Time, y = Norm)) +
  geom_boxplot(fill = col_polii, color = "black", width = 0.65, outlier.shape = NA, alpha = 0.9) +
  geom_jitter(width = 0.15, alpha = 0.5, size = 0.9, color = col_polii) +
  theme_classic(base_size = 12) +
  theme(
    panel.background = element_rect(fill = "white", color = NA),
    plot.background  = element_rect(fill = "white", color = NA)
  ) +
  labs(title = "PolII_Ser5 (0–5)",
       x = "time (min)", y = "Mean(PolII_Ser5) / Mean(DAPI)")
print(p_pol)

ggsave(file.path(input_dir, "BOX_PolII_Ser5_by_time_0-5.png"),
       p_pol, width = 7.5, height = 5, dpi = 300, bg = "white")

# ---------- Plot 2 : V5-TBP1 ----------
df_v5 <- dat_long %>% filter(Channel == "V5-TBP1")
p_v5 <- ggplot(df_v5, aes(x = Time, y = Norm)) +
  geom_boxplot(fill = col_v5, color = "black", width = 0.65, outlier.shape = NA, alpha = 0.9) +
  geom_jitter(width = 0.15, alpha = 0.5, size = 0.9, color = col_v5) +
  theme_classic(base_size = 12) +
  theme(
    panel.background = element_rect(fill = "white", color = NA),
    plot.background  = element_rect(fill = "white", color = NA)
  ) +
  labs(title = "V5-TBP1 normalisé par DAPI (0–5)",
       x = "time (min)", y = "Mean(V5-TBP1) / Mean(DAPI)")
print(p_v5)

ggsave(file.path(input_dir, "BOX_V5-TBP1_by_time_0-5.png"),
       p_v5, width = 7.5, height = 5, dpi = 300, bg = "white")

# --- Infos pratiques ---
cat("Fichiers lus :", length(files), "\n",
    "time inclus :", paste(levels(dat_long$Time), collapse = ", "), "\n")
