# ===== Nascent RNA — deux plots, filtré 0–5, catégories: Neg0, 0, 3h, 6h, Neg24, 24h =====
library(tidyverse)
library(readxl)
library(stringr)

choose_input_dir <- function(default = "/Users/tom/Downloads/Fiji_Results") {
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

# ---------- Fichiers ----------
files_csv  <- list.files(input_dir, pattern = "(?i)csv$",            full.names = TRUE)
files_xlsx <- list.files(input_dir, pattern = "(?i)\\.(xlsx|xls)$",  full.names = TRUE)
files <- c(files_csv, files_xlsx)
if (!length(files)) stop("Aucun CSV/XLSX trouvé dans : ", input_dir)

# ---------- Lecture + normalisation ----------
read_any <- function(f) {
  bn  <- basename(f)
  ext <- tolower(tools::file_ext(bn))

  df <- tryCatch({
    if (ext %in% c("xlsx","xls")) read_excel(f)
    else if (ext == "csv" || grepl("csv$", bn, ignore.case = TRUE)) readr::read_csv(f, show_col_types = FALSE)
    else stop("extension non reconnue")
  }, error = function(e) { message(">> Skip lecture: ", bn, " — ", e$message); return(NULL) })

  if (is.null(df) || !nrow(df)) { message(">> Skip vide: ", bn); return(NULL) }

  names(df) <- gsub("\\s+", "_", names(df))
  needed <- c("Mean_Green","Mean_Red","Mean_DAPI")
  if (!all(needed %in% names(df))) { message(">> Skip colonnes manquantes: ", bn); return(NULL) }

  if (!"Condition" %in% names(df)) df$Condition <- "All"
  if (!"ROI_Index" %in% names(df)) df$ROI_Index <- seq_len(nrow(df))

  num_cols <- intersect(c("Mean_Green","Mean_Red","Mean_DAPI",
                          "IntDen_Green","IntDen_Red","IntDen_DAPI"), names(df))
  df <- df %>% mutate(across(all_of(num_cols), ~ suppressWarnings(as.numeric(.))))

  df %>%
    mutate(
      Nascent_RNA = Mean_Green / Mean_DAPI,   # vert
      V5_TBP1     = Mean_Red   / Mean_DAPI,   # rouge
      SourceFile  = tools::file_path_sans_ext(bn)
    ) %>%
    filter(is.finite(Nascent_RNA), is.finite(V5_TBP1))
}

all_dat <- purrr::map(files, read_any) %>% purrr::compact() %>% list_rbind()
if (!nrow(all_dat)) stop("Aucune ligne exploitable après lecture.")

# ---------- Long + filtre 0–5 ----------
dat_long <- all_dat %>%
  select(SourceFile, Condition, ROI_Index, Nascent_RNA, V5_TBP1) %>%
  pivot_longer(c(Nascent_RNA, V5_TBP1), names_to = "Channel", values_to = "Norm") %>%
  filter(between(Norm, 0, 0.05))

# ---------- Parsing & regroupement en catégories: Neg0, 0, 3h, 6h, Neg24, 24h ----------
order_levels <- c("Neg0","Neg24","3h","6h","24h")

dat_long <- dat_long %>%
  mutate(
    lower = tolower(SourceFile),

    # "X min" ou "X m"
    mins_str = str_match(lower, "(?<!\\d)(\\d+)\\s*(?:min|m)")[,2],
    # "X h / hr / hrs / hour / heures" (underscore/tiret autorisés ensuite)
    hrs_str  = str_match(lower, "(?<!\\d)(\\d+)\\s*(?:h|hr|hrs|hour|heures)")[,2],

    mins  = suppressWarnings(as.numeric(mins_str)),
    hrs   = suppressWarnings(as.numeric(hrs_str)),

    has_zero = str_detect(lower, "(^|[^0-9])0(?:\\s*(?:min|m))?(\\b|[^0-9])"),
    has_24   = str_detect(lower, "(^|[^0-9])24(\\b|[^0-9])") | (!is.na(mins) & mins==1440) | (!is.na(hrs) & hrs==24),

    # Catégorie finale selon le nom
    TimeGroup = case_when(
      str_detect(lower, "neg") & (has_zero | (!is.na(mins) & mins==0) | (!is.na(hrs) & hrs==0)) ~ "Neg0",
      str_detect(lower, "neg") & has_24                                                            ~ "Neg24",
      (!is.na(mins) & mins==0) | (!is.na(hrs) & hrs==0)                                            ~ "0",
      (!is.na(mins) & mins==180) | (!is.na(hrs) & hrs==3)                                          ~ "3h",
      (!is.na(mins) & mins==360) | (!is.na(hrs) & hrs==6)                                          ~ "6h",
      has_24                                                                                       ~ "24h",
      TRUE                                                                                         ~ NA_character_
    )
  ) %>%
  filter(!is.na(TimeGroup)) %>%
  mutate(
    TimeGroup = factor(TimeGroup, levels = order_levels, ordered = TRUE),
    Channel   = factor(Channel, levels = c("Nascent_RNA","V5_TBP1"),
                       labels = c("Nascent_RNA","V5-TBP1"))
  )

# ---------- Résumé diagnostique (utile pour vérifier) ----------
diag <- dat_long %>%
  count(Channel, TimeGroup, name = "n_points") %>%
  complete(Channel, TimeGroup, fill = list(n_points = 0)) %>%
  arrange(Channel, TimeGroup)
print(diag)

# ---------- Plots ----------
col_rna <- "#32CD32"
col_v5  <- "#D62728"

# Nascent RNA
df_rna <- dat_long %>% filter(Channel == "Nascent_RNA")
p_rna <- ggplot(df_rna, aes(TimeGroup, Norm)) +
  geom_boxplot(fill = col_rna, color = "black", width = 0.65,
               outlier.shape = NA, alpha = 0.9) +
  geom_jitter(width = 0.15, alpha = 0.6, size = 1.2, color = "black") +
  scale_x_discrete(
    labels = c(
      "Neg0"  = "No_EU",
      "Neg24" = "No_dTAG",
      "3h"    = "3H",
      "6h"    = "6H",
      "24h"   = "24H"
    )
  ) +
  theme_classic(base_size = 12) +
  labs(title = "Nascent_RNA (0–5)",
       x = "Temps", y = "Mean(Nascent_RNA) / Mean(DAPI)")
print(p_rna)
ggsave(file.path(input_dir, "BOX_Nascent_RNA_by_time_0-5.png"),
       p_rna, width = 7.5, height = 5, dpi = 300, bg = "white")

# V5-TBP1
df_v5 <- dat_long %>% filter(Channel == "V5-TBP1")
p_v5 <- ggplot(df_v5, aes(TimeGroup, Norm)) +
  geom_boxplot(fill = col_v5, color = "black", width = 0.65,
               outlier.shape = NA, alpha = 0.9) +
  geom_jitter(width = 0.15, alpha = 0.5, size = 0.9, color = col_v5) +
  scale_x_discrete(drop = FALSE) +
  theme_classic(base_size = 12) +
  theme(panel.background = element_rect(fill = "white", color = NA),
        plot.background  = element_rect(fill = "white", color = NA)) +
  labs(title = "V5-TBP1 (0–5)",
       x = "time", y = "Mean(V5-TBP1) / Mean(DAPI)")
print(p_v5)
ggsave(file.path(input_dir, "BOX_V5-TBP1_by_time_0-5.png"),
       p_v5, width = 7.5, height = 5, dpi = 300, bg = "white")

cat("Fichiers lus :", length(files), "\n",
    "Catégories présentes :", paste(levels(dat_long$TimeGroup), collapse = ", "), "\n")
