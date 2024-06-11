library(tibble)
library(dplyr)
library(tidyr)
library(sf)
library(ggplot2)
source("street_range_functions.R")

d <- readRDS("data_raw/crime_incidents_2024-06-11.rds") |>
  bind_rows(readRDS("data_raw/shotspotter_2024-06-11.rds"))

# transform city street range (12XX) to tigris street range (1200-1299)
d_street_ranges <- make_street_range(unique(d$address_x))

# match street ranges
d_street_ranges$street_ranges <-
  purrr::pmap(d_street_ranges, 
              query_street_ranges, 
              .progress = "querying street ranges")

# reduce to one geometry per city street range
d_street_ranges_sf <- 
  unnest(d_street_ranges, cols = c(street_ranges)) |>
  filter(!is.na(tlid)) |>
  group_by(address_x, x_min, x_max, x_name) |>
  summarize(tlid = paste(unique(tlid), collapse = "-"), 
            geometry = st_union(geometry)) |>
  st_as_sf()

d <- left_join(d, 
               d_street_ranges_sf |> select(address_x, tlid) |> st_drop_geometry(), 
               by = "address_x")

d_counts_by_street_range <- 
  d |>
  filter(!is.na(tlid)) |>
  group_by(address_x, tlid, category) |>
  tally() |>
  pivot_wider(names_from = category, 
              values_from = n) |>
  ungroup() |>
  left_join(d_street_ranges_sf, by = c("address_x", "tlid")) |>
  group_by(tlid, geometry) |>
  summarize(across(shotspotter:other, sum)) |>
  relocate(geometry, .after = last_col()) |>
  st_as_sf()

# visualize
neigh <-
  cincy::neigh_cchmc_2020 

the_roads <-
  tigris::roads(state = "39", county = "061") |>
  st_transform(st_crs(neigh)) |>
  st_crop(neigh) |>
  filter(MTFCC %in% c("S1100", "S1200"))

d_counts_by_street_range |>
  pivot_longer(shotspotter:other,
               names_to = "cat", 
               values_to = "count") |>
  mutate(cat = factor(cat, levels = c("violent", "property", "other", "shotspotter"))) |>
  filter(!is.na(count)) |>
  ggplot() +
  geom_sf(aes(linetype = MTFCC), data = the_roads, color = "light grey", linewidth = 1.5) +
  geom_sf(aes(color = count), linewidth = 1) +
  facet_wrap(~cat, ncol = 2, 
             labeller = labeller(cat = c(other = "Other Crimes", 
                                         property = "Property Crimes", 
                                         shotspotter = "Gunshots", 
                                         violent = "Violent Crimes"))) +
  viridis::scale_color_viridis(trans = "log") +
  CB::theme_map()

ggsave("crime_incident_map.svg", width = 14, height = 10)

# write gpkg file 
st_write(d_counts_by_street_range, 
         glue::glue("data/crimes_by_street_range_{Sys.Date()}.gpkg"), 
         append = FALSE)

message(
  scales::percent((nrow(filter(d, category != "shotspotter")) - sum(is.na(filter(d, category != "shotspotter")$tlid))) / nrow(filter(d, category != "shotspotter"))),
  " (n=",
  scales::number(sum(is.na(filter(d, category != "shotspotter")$tlid)), big.mark = ","),
  ") of all ",
  scales::number(nrow(filter(d, category != "shotspotter")), big.mark = ","),
  " crime incident records were matched to at least one census street range geography.")

message(
  scales::percent((nrow(filter(d, category == "shotspotter")) - sum(is.na(filter(d, category == "shotspotter")$tlid))) / nrow(filter(d, category == "shotspotter"))),
  " (n=",
  scales::number(sum(is.na(filter(d, category == "shotspotter")$tlid)), big.mark = ","),
  ") of all ",
  scales::number(nrow(filter(d, category == "shotspotter")), big.mark = ","),
  " shotspotter records were matched to at least one census street range geography.")
