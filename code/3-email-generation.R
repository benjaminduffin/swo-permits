
# Header ------------------------------------------------------------------

# Checking for SWO permits for vessels that can't be readily matched with a permit 
# Ben Duffin 8/22/2022

# 1- pullin in info from GARFO and SERO FOIA sites
# 2- comparing to vessels that couldn't be matched with a permit
# 3- generating emails (via .rmd or .qmd) to dealers inquiring about vessel 
# need to also pull in eDealer emails then 
# 4- filling table with notes/updates ({googledrive} package)


## ##
# this section takes input data and 

# Libraries ---------------------------------------------------------------


library(quarto)
library(here)
library(rmarkdown)


# Read data ---------------------------------------------------------------

swo_nomatch_s <- readRDS(here("output", "swo_vesPermit_nomatch_2022-09-02.rds")) # pick most recent

# convert actual NA to "Unknown" dealer names 


# Email gen ---------------------------------------------------------------

# write file (.qmd file will point here)

# for (i in unique(swo_nomatch_s$DEALER_NAME)) {
#   quarto_render(here("code", "4-email-template.qmd"), 
#                 output_format = "html", 
#                 output_file = here("output", "emails", paste0(i, "_swo_vesPermit_contact.html")), 
#                 params = list(dlr = i)
#                 )
# }

# rmarkdown version - .qmd isn't accessing env. variables? 
for (i in unique(swo_nomatch_s$Dealer.Id)) {
  rmarkdown::render("C:/Users/benjamin.duffin/Documents/R Projects/swo-permits/code/5-email-template.rmd", 
                output_format = "html_document", 
                output_file = here::here("output", "emails", paste0(i, "_swo_vesPermit_contact.html"))
  )
}


