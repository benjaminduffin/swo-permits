
# Header ------------------------------------------------------------------
# Checking for SWO permits for vessels that can't be readily matched with a permit 
# Ben Duffin 8/22/2022

# 1- pullin in info from GARFO and SERO FOIA sites
# 2- comparing to vessels that couldn't be matched with a permit
# 3- generating emails (via .rmd or .qmd) to dealers inquiring about vessel 
# need to also pull in eDealer emails then 
# 4- filling table with notes/updates ({googledrive} package)

# Load libraries ----------------------------------------------------------

library(writexl)
library(readxl)
library(plyr)
library(dplyr)
library(stringr)
library(stringdist)
library(targets)
library(here)

# Load Data ---------------------------------------------------------------

to_load <- list.files(path = here("data"))

# data structure string
df_names <- c("dlr_emails", "garfo", "hms", "sero", "swo")

dat_list <- list()
  
for (i in 1:length(to_load)) {
  dat_list[[i]] <- readRDS(file = here("data", to_load[i]))
}

names(dat_list) <- df_names

list2env(dat_list, globalenv())

# clean up 
rm(df_names, i, to_load, dat_list)

# Process Data ------------------------------------------------------------


# Matching ----------------------------------------------------------------


# -------------------------------------------------------------------------


