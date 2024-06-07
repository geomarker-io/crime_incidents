library(tidyverse)
library(sf)
library(lubridate)
source("street_range_functions.R")

# read in data 
d <- read_csv("https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
              col_types = cols_only(
                INSTANCEID = col_character(),
                INCIDENT_NO = col_character(),
                DATE_FROM = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                OFFENSE = col_character(),
                ADDRESS_X = col_character()
              ))



# write diagnostics.md
cat("#### Diagnostic Summary\n\n", file = "diagnostics.md", append = FALSE)
cat(glue::glue("Number of reported incidents on {Sys.Date()}: {nrow(d)}\n\n"), file = "diagnostics.md", append = TRUE)
cat(glue::glue("{nrow(d |> filter(is.na(ADDRESS_X)))} ({round(nrow(d |> filter(is.na(ADDRESS_X)))/nrow(d)*100)})% incidents with missing address\n\n"), file = "diagnostics.md", append = TRUE)

# clean up and match to coarse crime categories
crime_category <- yaml::read_yaml("data/crime_categories.yaml")
  
crime_category <- 
  tibble::tibble(category = unlist(purrr::map(crime_category, names)), 
                 OFFENSE = purrr::map(crime_category$category, ~.x[[1]])) |>
  unnest(cols = OFFENSE)

d <- 
  d |> 
  filter(DATE_FROM >= as.Date("2011-01-01")) |>    # filter by crime start date
  left_join(crime_category, by = "OFFENSE") |>  # assign offense crime_category
  distinct(.keep_all = TRUE) |> # remove duplicated rows
  filter(!is.na(ADDRESS_X))  # remove missing address

# count crimes by category
d_crime_by_street_range <- 
  d |> 
  mutate(n = 1) |> # add count for codec_category
  pivot_wider(names_from = category, 
              values_from = n) |> 
  mutate(across(c(property, violent, other), ~replace_na(.x, 0))) |>
  group_by(ADDRESS_X) |>
  summarize(across(c(violent, property, other), sum)) |>
  mutate(total = violent + property + other)

# transform city street range (12XX) to tigris street range (1200-1299)
street_ranges <- make_street_range(d_crime_by_street_range)
d_crime_by_street_range <- left_join(d_crime_by_street_range, street_ranges, by = "ADDRESS_X")

# match street ranges
d_crime_by_street_range$street_ranges <-
  purrr::pmap(d_crime_by_street_range, 
              query_street_ranges, 
              .progress = "querying street ranges")

cat(glue::glue("\n\n Number of unique street ranges: {nrow(d_crime_by_street_range)}\n\n"), file = "diagnostics.md", append = TRUE)

unmatched <- 
  unnest(d_crime_by_street_range, cols = c(street_ranges)) |>
  filter(is.na(tlid))

cat(glue::glue("{nrow(unmatched)} ({round(nrow(unmatched)/nrow(d_crime_by_street_range)*100)})% unmatched street ranges\n\n"), file = "diagnostics.md", append = TRUE)

# reduce to one geometry per city street range
sf_crimes_by_street_range <- 
  unnest(d_crime_by_street_range, cols = c(street_ranges)) |>
  filter(!is.na(tlid)) |>
  group_by(ADDRESS_X, violent, property, other, total) |>
  summarize(tlid = paste(unique(tlid), collapse = "-"), 
            geometry = st_union(geometry)) |>
  st_as_sf()

cat(glue::glue("{as.double(summarize(unmatched, sum(total)))} ({round(as.double(summarize(unmatched, sum(total)))/as.double(summarize(st_drop_geometry(ungroup(sf_crimes_by_street_range)), sum(total)))*100)})% unmatched incidents\n\n"), file = "diagnostics.md", append = TRUE)



# collapse tigris street ranges
sf_crimes_by_tigris_street_range <- 
  sf_crimes_by_street_range |>
  group_by(tlid, geometry) |>
  summarize(across(c(violent, property, other, total), sum)) |>
  st_as_sf()

# visualize
neigh <-
  cincy::neigh_cchmc_2020 

the_roads <-
  tigris::roads(state = "39", county = "061") |>
  st_transform(st_crs(neigh)) |>
  st_crop(neigh) |>
  filter(MTFCC %in% c("S1100", "S1200"))

ggplot(sf_crimes_by_tigris_street_range) +
  geom_sf(aes(linetype = MTFCC), data = the_roads, color = "light grey", linewidth = 1.5) +
  geom_sf(aes(color = total), linewidth = 1) +
  viridis::scale_color_viridis(trans = "log") +
  CB::theme_map()

ggsave("crime_incident_map.svg", width = 14, height = 10)

# write gpkg file 
st_write(sf_crimes_by_tigris_street_range, 
         "data/n_crimes_by_street_range_2024_06_07.gpkg", 
         append = FALSE)