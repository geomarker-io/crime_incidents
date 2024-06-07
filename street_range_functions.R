#' add suffixes to the end of these specific city street names to match tigris street names
add_suffix <-
  list(
    "ave" = c("e mcmicken", "w mcmicken", "mcgregor", "st james", "blair", "mckeone"))

suffix_replacements <-
  paste(add_suffix$ave, names(add_suffix["ave"])) |>
  purrr::set_names(add_suffix$ave)

make_street_range <- function(d) {
  d |>
    select(ADDRESS_X) |>
    # separate street numbers from street name
    separate_wider_regex(cols = ADDRESS_X, 
                         patterns = c(x_min = "^[0-9X]*", x_name = ".*"),
                         cols_remove = FALSE
    ) |>
    mutate(x_name = str_trim(x_name), # remove leading whitespace 
           # create min and max street range
           x_max = x_min,
           x_min = as.numeric(str_replace_all(x_min, "X", "0")), 
           x_max = as.numeric(str_replace_all(x_max, "X", "9")),
           # clean up street names to match tigris street names
           x_name = str_to_lower(x_name), 
           x_name = str_replace_all(x_name, fixed(" av"), " ave"),
           x_name = str_replace_all(x_name, fixed(" wy"), " way"),
           x_name = str_replace_all(x_name, fixed("east "), "e "),
           x_name = str_replace_all(x_name, suffix_replacements),
           x_name = str_replace_all(x_name, fixed("ave ave"), "ave")
    ) |>
    select(ADDRESS_X, x_min, x_max, x_name)
}

tigris_streets <- readRDS("data/tigris_streets.rds")

# returns all "intersecting" tigris street range address lines within intput street name and min/max for street number
query_street_ranges <- function(x_name, x_min, x_max, ...) {
  ## find street
  streets_contain <-
    tigris_streets |>
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
  return(tibble::tibble(
    name = NA,
    tlid = NA,
    number_min = NA, 
    number_max = NA, 
    geometry = NA
  ))
}

