library(tidyverse)

# no response data from:
# https://data.cincinnati-oh.gov/Safety/ShotSpotter-Incidents-by-Police-District/hgdz-xudz on 16 September 2022
download.file(
  "https://data.cincinnati-oh.gov/api/views/gexm-h6bt/files/8e9a29a3-1120-4187-ab83-655d17f05403?download=true&filename=CPD%20Disposition%20Text_No%20Response.xlsx",
  "data_raw/CPD_Disposition_Text_No_Response.xlsx"
)

no_resp_dispos <-
  readxl::read_xlsx("data_raw/CPD_Disposition_Text_No_Response.xlsx") |>
  magrittr::set_names(c("disposition", "response")) |>
  filter(!response == "response") |>
  pull(disposition)

saveRDS(no_resp_dispos, "data/no_resp_dispos.rds")
