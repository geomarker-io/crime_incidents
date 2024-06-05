library(tidyverse)
library(sf)
library(lubridate)
source("street_range_functions.R")

# download data 
options(timeout = 200)

download.file(
  "https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
  destfile = "data/crime_incidents_rawdata.csv"
)

# read in data 
d <- read_csv("data/crime_incidents_rawdata.csv",
              col_types = cols(
                DATE_REPORTED = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                DATE_FROM = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                DATE_TO = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                CLSD = col_factor(),
                DST = col_factor(),
                BEAT = col_factor(),
                LOCATION = col_factor(),
                THEFT_CODE = col_factor(), 
                FLOOR = col_factor(),
                SIDE = col_factor(),
                OPENING = col_factor(),
                HATE_BIAS = col_factor(),
                DAYOFWEEK = col_factor(),
                RPT_AREA = col_factor(),
                CPD_NEIGHBORHOOD = col_factor(),
                WEAPONS = col_factor(),
                DATE_OF_CLEARANCE = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                VICTIM_AGE = col_factor(),
                VICTIM_RACE = col_factor(),
                VICTIM_ETHNICITY = col_factor(),
                VICTIM_GENDER = col_factor(),
                SUSPECT_AGE = col_factor(),
                SUSPECT_RACE = col_factor(),
                SUSPECT_ETHNICITY = col_factor(),
                SUSPECT_GENDER = col_factor(),
                TOTALNUMBERVICTIMS = col_integer(),
                TOTALSUSPECTS = col_integer(),
                UCR_GROUP = col_factor(),
                ZIP = col_factor(),
                COMMUNITY_COUNCIL_NEIGHBORHOOD = col_factor(),
                SNA_NEIGHBORHOOD = col_factor()
              ))

glimpse(d)

# clean up and match to coarse crime categories
codec_category <- read_csv("crimeData_offense_codec_categories.csv") 

d <- 
  d |> 
  select(INSTANCEID, INCIDENT_NO, DATE_FROM, OFFENSE, address = ADDRESS_X) |>
  filter(DATE_FROM >= as.Date("2011-01-01")) |>    # filter by crime start date
  left_join(codec_category, by = "OFFENSE") |>  # assign offense codec_category
  distinct(.keep_all = TRUE) |> # remove duplicated rows
  filter(!is.na(address))  # remove missing address

# count crimes by category
d_crime_by_street_range <- 
  d |> 
  mutate(n = 1) |> # add count for codec_category
  pivot_wider(names_from = codec_category, 
              values_from = n) |> 
  mutate(across(c(property, violent, other), ~replace_na(.x, 0))) |>
  group_by(address) |>
  summarize(across(c(violent, property, other), sum))

# transform city street range (12XX) to tigris street range (1200-1299)
street_ranges <- make_street_range(d_crime_by_street_range)

d_crime_by_street_range <- left_join(d_crime_by_street_range, street_ranges, by = "address")

# match street ranges
d_crime_by_street_range$street_ranges <-
  purrr::pmap(d_crime_by_street_range, 
              query_street_ranges, 
              .progress = "querying street ranges")

# reduce to one geometry per city street range
sf_crimes_by_street_range <- 
  unnest(d_crime_by_street_range, cols = c(street_ranges)) |>
  filter(!is.na(tlid)) |>
  group_by(address, violent, property, other) |>
  summarize(tlid = paste(unique(tlid), collapse = "-"), 
            geometry = st_union(geometry)) |>
  st_as_sf()

# collapse tigris street ranges
sf_crimes_by_tigris_street_range <- 
  sf_crimes_by_street_range |>
  group_by(tlid, geometry) |>
  summarize(across(c(violent, property, other), sum)) |>
  st_as_sf()

# sanity check plot
ggplot(sf_crimes_by_tigris_street_range) +
  geom_sf(aes(color = violent), linewidth = 1) +
  viridis::scale_color_viridis(trans = "log") +
  CB::theme_map()

saveRDS(sf_crimes_by_tigris_street_range, "data/n_crimes_by_street_range_2024_06_05.rds")


# number streets unmatched
# number incidents unmatched