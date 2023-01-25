
library(tidyverse)
library(sf)
library(lubridate)

# CPD crime incidents
# https://data.cincinnati-oh.gov/Safety/ShotSpotter-Incidents-by-Police-District/hgdz-xudz
# This data represents reported Crime Incidents in the City of Cincinnati. 
# Incidents are the records, of reported crimes, collated by an agency for management. 
# Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. 
# This does not include police calls for service, arrest information, final case determination, or any other incident outcome data.

#=====================
# download data
#=====================

download.file(
  "https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
  sprintf("data/crime_incidents_rawdata_%s.csv", Sys.Date())
)

raw_data <- read_csv(sprintf("data/crime_incidents_rawdata_%s.csv", Sys.Date()),
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
  distinct(.keep_all = TRUE)  # remove duplicated rows
dim(d)

saveRDS(d, file=sprintf("data/crime_incidents_codec_categories_%s.rds", Sys.Date()))


#===============================================================
# group individual level data into incident level data
#===============================================================

d.by_ins <- d |> 
  select(INSTANCEID, INCIDENT_NO, DATE_FROM, codec_category, address_x) |> 
  distinct(.keep_all = TRUE) |> 
  filter(!is.na(address_x))    # remove NA addresses
dim(d.by_ins)  #361826

# check how many incidences have two or more codec categories:   
# d.by_ins |> 
#   select(INSTANCEID, INCIDENT_NO, codec_category) |> 
#   group_by(INSTANCEID, INCIDENT_NO) |> 
#   summarize(n=n()) |> 
#   filter(n > 1) |> dim()

# adding indicator variable to codec category so that each row represent a unique combination of instanceID and incident_no.
d.by_ins <- d.by_ins |> 
  mutate(n = 1) |> # add indicator
  pivot_wider(names_from = codec_category, 
              values_from = n) |> 
  mutate(property = replace_na(property, 0)) |> 
  mutate(violent = replace_na(violent, 0)) |> 
  mutate(other = replace_na(other, 0))
dim(d.by_ins) #353449

saveRDS(d.by_ins, file=sprintf("data/crime_incidents_codec_categories_byIncident_%s.rds", Sys.Date()))

#======================
#geospacial mapping
#======================

#' create unique set of address ranges & parse name, min, max street number
d_address_ranges <- d.by_ins |>
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

#' changes in city street names to match tigris street names
d_address_ranges <-
  d_address_ranges |>
  mutate(x_name = str_replace_all(x_name, fixed(" av"), " ave")) |>
  mutate(x_name = str_replace_all(x_name, fixed(" wy"), " way")) |>
  mutate(x_name = str_replace_all(x_name, fixed("east "), "e "))

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

streets |>
  st_drop_geometry() |>
  select(name) |>
  distinct() |>
  arrange(name) |>
  readr::write_csv("streets.csv")

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
  filter(x_min != "NA") |> 
  knitr::kable()
# 4253 of 11930 (35.6%) addresses have na street_ranges.
# 4173 of 11934 (35.0%) non-na addresses have na street_ranges.

d.by_ins.new <- left_join(d.by_ins, d_address_ranges, by = "address_x")

d.by_ins.new |>
  select(-x_max, -x_min, -x_name, -n) |>
  rename(date_time = DATE_FROM) |> 
  saveRDS(file = sprintf("data/crime_incidents_street_ranges_%s.rds", Sys.Date()))

message(
  scales::percent((nrow(d.by_ins.new) - sum(is.na(d.by_ins.new$street_ranges))) / nrow(d.by_ins.new)),
  " (n=",
  scales::number(sum(!is.na(d.by_ins.new$street_ranges)), big.mark = ","),
  ") of all ",
  scales::number(nrow(d.by_ins.new), big.mark = ","),
  " records were matched to at least one census street range geography.")
#94% (n=332,709) of all 353,449 records were matched to at least one census street range geography.

d.by_ins.new |>
  rowwise() |>
  mutate(n_street_ranges = list(nrow(street_ranges))) |>
  group_by(n_street_ranges) |>
  summarize(n = n()) |>
  arrange(desc(n)) |>
  mutate(`%` = scales::percent(n / sum(n), 1)) |>
  knitr::kable()

