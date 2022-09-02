
# Header ------------------------------------------------------------------

# Checking for SWO permits for vessels that can't be readily matched with a permit 
# Ben Duffin 8/22/2022

# 1- pullin in info from GARFO and SERO FOIA sites
# 2- comparing to vessels that couldn't be matched with a permit
# 3- generating emails (via .rmd or .qmd) to dealers inquiring about vessel 
  # need to also pull in eDealer emails then 
# 4- filling table with notes/updates ({googledrive} package)



# Libraries ---------------------------------------------------------------

library(RJDBC)
library(dotenv)
library(keyring)
library(writexl)
library(readxl)
library(plyr)
library(dplyr)
library(stringr)
library(targets)
library(here)
library(googlesheets4)

# File Structure ----------------------------------------------------------

# set up the file strucutre
dirs <- c("code", "data", "documentation",  "functions", "output")

for (i in 1:length(dirs)){
  if(dir.exists(dirs[i]) == FALSE){
    dir.create(dirs[i])
  }
}

## ADD DIRS TO GITIGNORE
# just new lines 
# data/
# output/


# {dotenv} setup and secrets ----------------------------------------------

# create a .env file with a value pair for the DB connection string 
# add a line after completed text 

## ADD TO GITIGNORE
# just new lines 
# .env

# load .env
load_dot_env(".env") # then access with Sys.getenv("HMS_EDEALER")

# keyring
keyring::key_list("HMS-eDealer")$username
keyring::key_get("HMS-eDealer", "BENJAMINDUFFIN")

# Data pull ---------------------------------------------------------------


#### Dealer emails ####

# create driver object 
# point this to your local ojdbc8.jar file! 
jdbcDriver <- JDBC(driverClass = "oracle.jdbc.OracleDriver",
                   classPath="C:/instantclient-basic-windows.x64-21.6.0.0.0dbru/instantclient_21_6/ojdbc8.jar") #CHANGE


# Create connection to the database 
jdbConnection <- dbConnect(jdbcDriver, 
                           Sys.getenv("HMS_EDEALER"), 
                           user = keyring::key_list("HMS-eDealer")$username, 
                           password = keyring::key_get("HMS-eDealer", "BENJAMINDUFFIN"))


# query string
email_qry <- "SELECT
                PARTICIPANT_ID, 
                DEALER_NAME,
                PHONE, 
                EMAIL1||', '||EMAIL2||', '||EMAIL3||', '||EMAIL4 AS EMAILS
              FROM
                EDEALER.DATA_LIST_DEALERS"


# send query 
dlr_emails <- dbGetQuery(jdbConnection, email_qry)

# remove dupes 
dlr_emails <- dlr_emails[!duplicated(dlr_emails), ]

# save data to data folder 
saveRDS(dlr_emails, here("data", paste0("dealer_email_list_", Sys.Date(), ".rds")))



#### Permits ####
## GARFO - SWO, HMS incidental
garfo <- read.csv("https://www.greateratlantic.fisheries.noaa.gov/public/public/web/NEROINET/permits/data/permits_2022.csv", 
                  stringsAsFactors = F)

# subset just for HMS permits 
garfo <- subset(garfo, INCIDENTAL.HMS.SQUID.TRAWL == 1)

# write file
saveRDS(garfo, here("data", paste0("GARFO_permits_", Sys.Date(), ".rds")))


## HMS Permits (OAP) 
hmsoap <- read.csv("https://www.greateratlantic.fisheries.noaa.gov/public/public/web/NEROINET/permits/data/tuna_permits.csv", 
                   stringsAsFactors = F)

# write file
saveRDS(hmsoap, here("data", paste0("HMS_OAP_permits_", Sys.Date(), ".rds")))

## SERO
sero <- read.csv("https://noaa-sero.s3.amazonaws.com/drop-files/pims/FOIA+Vessels+All.csv", stringsAsFactors = F)

# subset just for HMS permits 
sero$permit_type <- str_split_fixed(sero$Permit, pattern = "-", n = 2)[,1]
sero_hms_permits <- c('SFD','SFH','SFI','CCSB')

sero <- subset(sero, permit_type %in% sero_hms_permits)

# write file 
saveRDS(sero, here("data", paste0("SERO_permits_", Sys.Date(), ".rds")))


#### SWO vessels from Steve ####
# gs4_auth(email = "benjamin.duffin@noaa.gov") # run to authenticate google sheets/tidyverse communication
swo <- read_sheet("https://docs.google.com/spreadsheets/d/19crtA31a9EWdbpWOrHA0Wkdg35-3ckB3OViZzPBuu5Y/edit?usp=sharing", 
                  col_types = "c") %>%
  as.data.frame()


# write file
saveRDS(swo, here("data", paste0("SWO_landings_noMatch_", Sys.Date(), ".rds")))

# Clean up  ---------------------------------------------------------------

# check for open connections and close any 
var <- as.list(.GlobalEnv)
var_names <- names(var)

for (i in seq_along(var_names)){
  if (class(var[[var_names[i]]]) == "JDBCConnection"){
    dbDisconnect(var[[var_names[i]]])
  }
}

# remove objects
rm(list = ls())
