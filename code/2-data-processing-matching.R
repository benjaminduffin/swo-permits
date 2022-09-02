
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
library(here)

# Load functions ----------------------------------------------------------
# match data exactly, return info
match_permit <- function(orphan_data, match_data) {
  # extract input data names 
  dat_name <- gsub("*_s", "", deparse(substitute(match_data)))
  
  match_var1 <- paste0(dat_name, "_match")
  
  match_var2 <- paste0(dat_name, "_match_dates")
  
  
  x <- subset(match_data, VESSEL_ID %in% orphan_data$Vessel.Id) %>%
    mutate(!!match_var1 := paste0(PERMIT_TYPE, "-", PERMIT),
           !!match_var2 := paste0(EFFDATE, " - ", EXPDATE), 
           Vessel.Id = VESSEL_ID) %>%
    select(Vessel.Id, match_var1, match_var2)
  
  return(x)
}

# similar, but standardized return field names ** used 
match_permit2 <- function(orphan_data, match_data) {
  x <- subset(match_data, VESSEL_ID %in% orphan_data$Vessel.Id) %>%
    mutate(NOTES = paste0(PERMIT_TYPE, "-", PERMIT, "; Effective Date: ", EFFDATE, 
                          ", Exp Date: ", EXPDATE),
           Vessel.Id = VESSEL_ID) %>%
    select(Vessel.Id, NOTES)
  return(x)
}

# Load Data ---------------------------------------------------------------

to_load <- list.files(path = here("data"))

# df names string
df_names <- c("dlr_emails", "garfo", "hms", "sero", "swo")

# make empty list 
dat_list <- list()

# loop and load 
for (i in 1:length(to_load)) {
  dat_list[[i]] <- readRDS(file = here("data", to_load[i]))
}

# name dfs
names(dat_list) <- df_names

# bring to global env
list2env(dat_list, globalenv())

# clean up 
rm(df_names, i, to_load, dat_list)

# Process Data ------------------------------------------------------------

## Now, we need to pull out the info for each unique vessel in the SWO data 
  # and search through the available permit info for each

## First, we can create a dataframe with all of the permits for each vessel from all sources 

# Garfo
garfo_s <- garfo %>% 
  select(HULL.ID, PERMIT) %>% 
  mutate(permit_type = "HMS Squid Incidental", 
         EFFECTIVE_DATE = NA, 
         EXP_DATE = "2022-12-31") 

# Sero 
sero_s <- sero %>% 
  select(Vessel_Id, Permit, permit_type, Effective_Date, Expiration_Date)

# HMS
hms_s <- hms %>% 
  mutate(ISSUE.DATE.asdate = as.Date(ISSUE.DATE, format = "%b %d, %Y"), 
         CATEGORY = ifelse(CATEGORY == "CHARTER/HEADBOAT" & CHB_ENDORSEMENT == "Y", 
                           "CHB_CommEnd", CATEGORY), 
         EXP.DATE = "2022-12-31") %>%
  select(HULL.ID, PERMIT.NUMBER, CATEGORY, ISSUE.DATE.asdate, EXP.DATE) 

# rename all similar 
var_names <- c("VESSEL_ID", "PERMIT", "PERMIT_TYPE", "EFFDATE", "EXPDATE")

names(garfo_s) <- var_names
names(sero_s) <- var_names
names(hms_s) <- var_names


## now lets pull out the vessels from swo landings 
# fix names 
names(swo) <- make.names(names(swo))
glimpse(swo)

# grab unique vessel, date
swo_s <- swo %>% 
  select(Vessel.Id, Date.Landed) %>%
  mutate(Date.Landed = as.Date(Date.Landed, format = "%m/%d/%Y")) %>%
  distinct()
  


# Matching ----------------------------------------------------------------

# take a look at what is present in the data 
table(swo_s$Vessel.Id %in% garfo_s$VESSEL_ID)
table(swo_s$Vessel.Id %in% sero_s$VESSEL_ID) 
table(swo_s$Vessel.Id %in% hms_s$VESSEL_ID)

garfo_s[garfo_s$VESSEL_ID %in% intersect(swo_s$Vessel.Id, garfo_s$VESSEL_ID), ]
sero_s[sero_s$VESSEL_ID %in% intersect(swo_s$Vessel.Id, sero_s$VESSEL_ID), ]
hms_s[hms_s$VESSEL_ID %in% intersect(swo_s$Vessel.Id, hms_s$VESSEL_ID), ]


## matching function - exact matching 
merge(swo_s, match_permit(swo_s, garfo_s), all.x = T)

# results 
match_permit(swo_s, sero_s)
match_permit(swo_s, hms_s)
match_permit(swo_s, garfo_s)

# matching vessels
vessel_with_match <- c(match_permit(swo_s, sero_s)$Vessel.Id, 
                       match_permit(swo_s, hms_s)$Vessel.Id, 
                       match_permit(swo_s, garfo_s)$Vessel.Id)

# matching data 
match_permit2(swo_s, sero_s) 
match_permit2(swo_s, garfo_s)
match_permit2(swo_s, hms_s)


# and to account for the fact that one vessel might have multiple permits... 
# generate data
match_from_permits <- bind_rows(match_permit2(swo_s, sero_s), 
                                match_permit2(swo_s, garfo_s),
                                match_permit2(swo_s, hms_s)
                                ) %>%
  group_by(Vessel.Id) %>% 
  summarize(NOTES = str_c(NOTES, collapse = '; '))
  

# subset out the data from swo that matches
swo_match <- subset(swo, Vessel.Id %in% vessel_with_match)

# merge int he matching ? 

# Unmatched data prep for emails ------------------------------------------

## Need: 
# -   Dealer name, emails,  (from PID) 
# -   Vessel ID
# -   SAFIS Dealer Report ID
# -   Dealer Ticket No
# -   Date Landed
# -   Federal Filename
# -   rpt qty??

# subset out the non-matching rows
swo_nomatch <- subset(swo, !(Vessel.Id %in% vessel_with_match))


# add note w/ date of contact for email
# swo_nomatch$NOTES <- paste("Emailed dealer", Sys.Date(), "requesting information")  ## save for later

# get info for table 
swo_nomatch_s <- swo_nomatch %>% 
  select(Dealer.Id, Vessel.Id, SAFIS.Dealer.Report.Id, Dealer.Ticket.Number, Date.Landed, Federal.File.Name, Common.Name, Weight..lbs.)


# merge in the dealer info from dealer emails 
swo_nomatch_s <- merge(swo_nomatch_s, dlr_emails, 
                       by.x = "Dealer.Id", by.y = "PARTICIPANT_ID", 
                       all.x = T)


# convert actual NA to "Unknown" dealer names 
swo_nomatch_s$DEALER_NAME <- ifelse(is.na(swo_nomatch_s$DEALER_NAME), "Unknown", swo_nomatch_s$DEALER_NAME)

# save this data to reference for email generation 

saveRDS(swo_nomatch_s, here("output", paste0("swo_vesPermit_nomatch_", Sys.Date(), ".rds")))

rm(list =ls())

# Testing -----------------------------------------------------------------

## so, stringdistnace probably isn't worth the trouble due to the similarity in 
# numbers across actually different CG #s

#testing 
## 
a <- sero_s %>% 
  mutate(Vessel.Id = VESSEL_ID) %>%
  select(Vessel.Id, EFFDATE, EXPDATE) %>%
  filter(!is.na(Vessel.Id))
  
  
t <- stringdist_join(swo_s[!is.na(swo_s$Vessel.Id), ], a, by = c("Vessel.Id"), 
                     mode = "left", distance_col = "distance", method = "jw")


t <- apply(t, 2, function(x) x > 0.1 <- NA)
rm(list = ls())

# match_dat <- subset(garfo_s, VESSEL_ID %in% swo_s$Vessel.Id) %>%
#   mutate(garfo_match = paste0(PERMIT_TYPE, "-", PERMIT), 
#          garfo_match_dates = paste0(EFFDATE, " - ", EXPDATE), 
#          Vessel.Id = VESSEL_ID) %>%
#   select(Vessel.Id, garfo_match, garfo_match_dates) %>% 
#   right_join(., swo_s)


# -------------------------------------------------------------------------


