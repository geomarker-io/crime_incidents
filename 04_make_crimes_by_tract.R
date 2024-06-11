library(tidyverse)
library(sf)
library(fr)

n_crimes_by_street_range <- st_read("data/crimes_by_street_range_2024-06-11.gpkg")

n_crimes_by_tract <- st_intersection(n_crimes_by_street_range, 
                      cincy::tract_tigris_2020 |> st_transform(st_crs(n_crimes_by_street_range)))

n_crimes_by_tract <- 
  n_crimes_by_tract |>
  st_drop_geometry() |>
  group_by(census_tract_id_2020) |>
  summarize(across(shotspotter:other, \(x) sum(x, na.rm = TRUE)))

# save codec 
d_tdr <-
  n_crimes_by_tract |>
  as_fr_tdr(
    name = "crime_incidents",
    version = "0.4.0",
    title = "Crime Incidents",
    homepage = "https://geomarker.io/crime_incidents",
    description = "Number of reported crimes by census tract"
  )

d_tdr <- 
  d_tdr |>
  update_field("census_tract_id_2020", 
               description = "census tract identifier") |>
  update_field("violent", 
               description = "number of violent crimes") |>
  update_field("property", 
               description = "number of property crimes") |>
  update_field("other", 
               description = "number of other crimes") |>
  update_field("shotspotter", 
               description = "number of gunshots") 

write_fr_tdr(d_tdr, dir = "data")

# save gpkg
n_crimes_by_tract <- left_join(n_crimes_by_tract, cincy::tract_tigris_2020, by = "census_tract_id_2020") |>
  st_as_sf()

mapview::mapview(n_crimes_by_tract, zcol = "violent")

st_write(n_crimes_by_tract, 
         glue::glue("data/crimes_by_tract_{Sys.Date()}.gpkg"), 
         append = FALSE)
