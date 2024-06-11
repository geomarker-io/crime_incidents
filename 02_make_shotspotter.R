library(dplyr)
no_resp_dispos <- readRDS("data/no_resp_dispos.rds")

shot_spotter_csv_url <-
  glue::glue(
    "https://data.cincinnati-oh.gov/api",
    "/views/gexm-h6bt/rows.csv",
    "?query=select%20*%20where%20(%60incident_type_desc%60%20%3D%20%27SHOT%20SPOTTER%20ACTIVITY%27)",
    "&read_from_nbe=true&version=2.1&accessType=DOWNLOAD"
  )

raw_data <-
  readr::read_csv(shot_spotter_csv_url,
                  col_types = readr::cols_only(
                    ADDRESS_X = "character",
                    CREATE_TIME_INCIDENT = readr::col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                    DISPOSITION_TEXT = "factor"
                  )) |>
  rename(date_time = CREATE_TIME_INCIDENT, 
         address_x = ADDRESS_X, 
         dispos = DISPOSITION_TEXT)

# exclude data with missing address, date, or disposition
d <-
  raw_data |>
  na.omit() |>
  filter(!dispos %in% no_resp_dispos) |>
  select(-dispos) |>
  mutate(category = "shotspotter")

saveRDS(d, glue::glue("data_raw/shotspotter_{Sys.Date()}.rds"))
