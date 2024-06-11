library(readr)
library(tidyr)
library(dplyr)
library(lubridate)

# read in data 
raw_data <- read_csv("https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
                     col_types = cols_only(
                       DATE_FROM = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                       OFFENSE = col_character(),
                       ADDRESS_X = col_character()
                     )) |>
  rename(date_time = DATE_FROM, 
         offense = OFFENSE, 
         address_x = ADDRESS_X)

# clean up and match to coarse crime categories
crime_category <- yaml::read_yaml("data/crime_categories.yaml")
  
crime_category <- 
  tibble::tibble(category = unlist(purrr::map(crime_category, names)), 
                 offense = purrr::map(crime_category$category, ~.x[[1]])) |>
  unnest(cols = offense)

d <- 
  raw_data |> 
  filter(date_time >= as.Date("2011-01-01")) |>    # filter by crime start date
  distinct(.keep_all = TRUE) |> # remove duplicated rows
  filter(!is.na(address_x)) |> # remove missing address
  left_join(crime_category, by = "offense") |> # assign offense crime_category
  select(-offense)

saveRDS(d, glue::glue("data_raw/crime_incidents_{Sys.Date()}.rds"))

