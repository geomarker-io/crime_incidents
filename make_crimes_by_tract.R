library(tidyverse)
library(sf)

n_crimes_by_street_range <- readRDS("data/n_crimes_by_street_range_2024_06_05.rds")

n_crimes_by_tract <- st_intersection(n_crimes_by_street_range, 
                      cincy::tract_tigris_2020 |> st_transform(st_crs(n_crimes_by_street_range)))

n_crimes_by_tract <- 
  n_crimes_by_tract |>
  st_drop_geometry() |>
  group_by(census_tract_id_2020) |>
  summarize(across(c(violent, property, other), sum))

n_crimes_by_tract <- left_join(n_crimes_by_tract, cincy::tract_tigris_2020, by = "census_tract_id_2020") |>
  st_as_sf()

mapview::mapview(n_crimes_by_tract, zcol = "violent")

saveRDS(n_crimes_by_tract |> st_drop_geometry(), "data/n_crimes_by_tract_2024_06_05.rds")
