Purpose

This repository contains scripts (in R and ImageJ macro) designed to facilitate quantification and analysis of microscopy image signals, for example DAPI/Green/Red channels, normalisation, batch processing, filtering and downstream analysis.
It aims to streamline typical image-analysis workflows (especially for cell biology / staining experiments) by providing reusable and automated tools.

Key Features

ImageJ macro scripts (e.g., BATCH_DAPI_Normalize_Green_Red_v5_setChannel.ijm, SIMPLE_DAPI_Normalize_Green_Red_v5_setChannel.ijm) to normalise channel intensities and set channel assignment.

R scripts (e.g., BP-Filter.R, BP-Filter_Staining1.R, BP_Filtered_Nascent.R) to filter, process and analyse extracted signal data.

Designed for batch processing large numbers of images, enabling consistent quantification across experiments.

Flexible use: both a “simple” path and a “batch” path depending on experiment size and complexity.

Dependencies & Requirements

ImageJ (or FIJI) with macro support, capable of running the .ijm scripts.

R (version ≥ X.X) — with packages for data manipulation (e.g., dplyr), plotting (e.g., ggplot2) and possibly reading/writing Excel/CSV.

A directory structure with raw microscopy images organised in a way that the macros expect (see Usage below).

Basic familiarity with microscopy image channels and normalisation concepts.

Repository Contents / File Structure
Signal_quantification/
├── BATCH_DAPI_Normalize_Green_Red_v5_setChannel.ijm
├── SIMPLE_DAPI_Normalize_Green_Red_v5_setChannel.ijm
├── BP-Filter.R
├── BP-Filter_Staining1.R
├── BP_Filtered_Nascent.R
└── .gitattributes

ImageJ macros (files ending .ijm): these perform main image-processing tasks (normalisation, channel assignment).

R scripts: perform the filtering, analysis and perhaps plotting of the data extracted from the ImageJ step.

.gitattributes: Git attributes file for repository settings (line endings, etc.).

Usage / Workflow

Here is a typical workflow:

Prepare your microscopy images

Organise images into folders (for example by experiment, condition, date).

Ensure that your images have the channels expected: DAPI (nuclei), Green, Red.

If using batch mode, ensure naming convention is consistent.

Run ImageJ macro

Open FIJI/ImageJ.

Load the macro (BATCH_DAPI_Normalize_Green_Red_v5_setChannel.ijm or SIMPLE_DAPI_Normalize_Green_Red_v5_setChannel.ijm).

Configure channel assignment if prompted (e.g., DAPI = channel 1, Green = channel 2, Red = channel 3).

Choose folder of raw images. The macro will process each image: normalise intensities, set channels, and export signal-data (e.g., CSV or other intermediate file) into an output folder.

Run R filtering/analysis

In R, open the script BP-Filter.R (or the variant BP-Filter_Staining1.R, BP_Filtered_Nascent.R) depending on your experiment type.

Adjust input path to the folder where the ImageJ macro output resides.

Run the script: it will load the extracted signal data, apply filtering criteria (e.g., remove outliers, background correction), summarise the data, and optionally produce plots.

Review results

Inspect output tables and plots.

Compare conditions, replicate images, summarise statistics (mean, median, standard deviation, etc.).

If needed refine filtering thresholds or revisit normalisation.

Examples

Here is a short example of how one might call the scripts:

Suppose images are in raw_images/ConditionA/ with DAPI/Green/Red channels.

Run in ImageJ: select folder raw_images/ConditionA/, macro produces processed/ConditionA/ and data/ConditionA_signals.csv.

Then in R:
source("BP-Filter.R")
data <- read.csv("data/ConditionA_signals.csv")
# filtering, summarisation

You might then plot e.g. Green vs Red signal intensity per cell, or generate violin plots by condition.

Configuration / Parameterisation

The macros may include parameters at the top of the script for channel numbers, output folder path, threshold values; adjust these as needed.

In the R scripts you will find variables at the top (e.g., input_path <- "...", output_path <- "...", threshold_value <- ...) which you should set for your experiment.

If your imaging setup uses different channel ordering (e.g., Red first, then Green), you will need to modify the macro accordingly.

Output & Interpretation

The main output of the image-processing step is (per image) a table of quantified signals (for example nucleus area, total intensity in each channel).

The R filtering step produces cleaned tables and often summary statistics or plots (e.g., per-condition averages, distribution of intensities, correlation between channels).

Interpretation:

Compare signal intensities between conditions (e.g., treated vs untreated).

Assess whether normalisation succeeded (low variation in DAPI, consistent channel ratios).

Visualise whether filtering removed unwanted artefacts or outliers.

You may export final tables in CSV or use them for downstream statistical tests as appropriate for your experiment design.

Best practices & Tips

Keep a consistent naming convention for your raw files (include condition, replicate number, date) so that downstream filtering/plotting is straightforward.

Run the macros on a small subset first to check that channel assignment, normalisation and output file format behave as expected.

Verify that DAPI channel intensities are stable across images—large variation may indicate imaging issues (e.g., different exposure).

In R filtering: inspect the distribution of values before and after filtering (e.g., via histograms) to ensure you’re not inadvertently removing valid data.

Document any manual adjustments you make (e.g., threshold values), so that your workflow is reproducible.

If you add new conditions or channels (e.g., a fourth channel), update the macros/scripts accordingly and annotate the changes.
