
library(tidyverse)
library(sf)
library(lubridate)


# call for service with no response
#https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Police-Calls-for-Servic/gexm-h6bt

# CPD crime incidents
# https://data.cincinnati-oh.gov/Safety/ShotSpotter-Incidents-by-Police-District/hgdz-xudz
# This data represents reported Crime Incidents in the City of Cincinnati. 
# Incidents are the records, of reported crimes, collated by an agency for management. 
# Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. 
# This does not include police calls for service, arrest information, final case determination, or any other incident outcome data.

download.file(
  "https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
  "crime_incidents_rawdata.csv"
)

raw_data <- read_csv("crime_incidents_rawdata.csv",
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
dim(raw_data)

codec_category <- read_csv("crimeData_offense_codec_categories.csv") 

d <- raw_data |> 
  filter(DATE_FROM >= mdy("1/1/2011")) |>    # filter by crime start date
  left_join(codec_category, by = "OFFENSE") |>  # assign offense codec_category
  rename(address_x = ADDRESS_X) |> 
  unique()  # remove duplicated rows

dim(d)

saveRDS(d, "crime_incidents_codec_categories.rds")


#======================
#geospacial mapping
#======================

#' create unique set of address ranges & parse name, min, max street number
d_address_ranges <- d |>
  filter(!is.na(address_x)) |> 
  group_by(address_x) |>
  tally() |>
  arrange(desc(n)) |>
  tidyr::extract(address_x,
                 into = c("x_min", NA, "x_max", NA, "x_name"),
                 regex = "(^[0-9X]*)([-]?)([0-9X]*)([ ]*)(.*)",
                 remove = FALSE) |>
  mutate(across(c(x_max, x_min), na_if, "")) |>
  mutate(across(x_max, coalesce, x_min)) |>
  mutate(x_min = gsub("X", "0", x_min),
         x_max = gsub("X", "9", x_max)) |>
  mutate(x_name = str_to_lower(x_name))

#' change "av" to "ave" in city street names to match tigris street names
d_address_ranges <-
  d_address_ranges |>
  mutate(x_name = str_replace_all(x_name, fixed(" av"), " ave"))

#' add suffixes to the end of these specific city street names to match tigris street names
add_suffix <-
  list(
    "ave" = c("e mcmicken", "w mcmicken", "mcgregor", "st james", "blair", "mckeone"))

suffix_replacements <-
  paste(add_suffix$ave, names(add_suffix["ave"])) |>
  purrr::set_names(add_suffix$ave)

d_address_ranges <-
  d_address_ranges |>
  mutate(x_name = str_replace_all(x_name, suffix_replacements)) |>
  mutate(x_name = str_replace_all(x_name, fixed("ave ave"), "ave"))

#  mutate(x_name = str_replace_all(x_name, fixed("east tower"), "e tower")) |> 
#  mutate(x_name = str_replace_all(x_name, fixed("highforest"), "high forest"))
  

# https://www2.census.gov/geo/pdfs/maps-data/data/tiger/tgrshp2020/TGRSHP2020_TechDoc.pdf
streets <-
  tigris::address_ranges(state = "39", county = "061", year = 2021) |>
  select(tlid = TLID,
         name = FULLNAME,
         LFROMHN, RFROMHN,
         LTOHN, RTOHN) |>
  mutate(across(ends_with("HN"), as.numeric)) |>
  dplyr::rowwise() |>
  transmute(name = str_to_lower(name),
            tlid = as.character(tlid),
            number_min = min(LFROMHN, RFROMHN, LTOHN, RTOHN, na.rm = TRUE),
            number_max = max(LFROMHN, RFROMHN, RTOHN, LTOHN, na.rm = TRUE)) |>
  ungroup()

#' returns all "intersecting" tigris street range address lines within intput street name and min/max for street number
query_street_ranges <- function(x_name, x_min, x_max, ...) {
  ## find street
  streets_contain <-
    streets |>
    filter(name == x_name)
  ## return range that contains both min and max street number, if available
  range_contain <-
    streets_contain |>
    filter(number_min < x_min & number_max > x_max)
  if (nrow(range_contain) > 0) return(range_contain)
  # if not available, return ranges containing either the min or max street number
  range_partial <-
    streets_contain |>
    filter(between(number_min, x_min, x_max) |
             between(number_max, x_min, x_max))
  if (nrow(range_partial) > 0) return(range_partial)
  # if nothing available, return NA
  return(NA)
}

query_street_ranges("vine st", 2300, 2399)
query_street_ranges("westwood northern blvd", 1900, 1999)
query_street_ranges("rockdale ave", 600, 699)
query_street_ranges("westwood northern blvd", 11900, 21999) # should return NA
query_street_ranges("e mcmicken ave", 00, 99)
query_street_ranges("rapid run pike", 4530, 4599)

## streets |>
##   filter(name %in% c("saint james ave", "st james ave")) |>
##   mapview::mapview(zcol = "name")

d_address_ranges$street_ranges <-
  purrr::pmap(d_address_ranges, query_street_ranges, .progress = "querying street ranges")

d_address_ranges |>
  rowwise() |>
  mutate(n_street_ranges = list(nrow(street_ranges))) |>
  group_by(n_street_ranges) |>
  summarize(n = n()) |>
  mutate(`%` = scales::percent(n / sum(n), 1)) |>
  knitr::kable()

d_address_ranges |>
  filter(is.na(street_ranges)) |>
  filter(!is.na(x_min)) |> 
  knitr::kable()
# 4285 of 11971 (35.8%) have na street_ranges.

d.new <- left_join(d, d_address_ranges, by = "address_x")

d.new |>
  select(-x_max, -x_min, -x_name, -n) |>
  saveRDS("crime_incidents_street_ranges.rds")
