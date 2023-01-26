library(sf)
library(dplyr)
library(ggplot2)

d <- readRDS("data/crime_incidents_street_ranges.rds")

d <- d |>
  filter(!is.na(street_ranges)) |>
  group_by(address_x, street_ranges) |>
  summarize(n = n()) |>
  rowwise() |>
  mutate(geometry = st_sfc(st_union(street_ranges))) |>
  st_as_sf() |>
  select(-street_ranges) |>
  arrange(n)

mapview::mapview(filter(d, n > 5), zcol = "n")

neigh <-
  cincy::neigh_cchmc_2020 

the_roads <-
  tigris::roads(state = "39", county = "061") |>
  st_transform(st_crs(neigh)) |>
  st_crop(neigh) |>
  filter(MTFCC %in% c("S1100", "S1200"))

ggplot(d) +
  geom_sf(aes(linetype = MTFCC), data = the_roads, color = "light grey", linewidth = 1.5) +
  geom_sf(aes(color = n), linewidth = 1) +
  viridis::scale_color_viridis(trans = "log") +
  CB::theme_map()

ggsave("crime_incident_map.svg", width = 14, height = 10)


