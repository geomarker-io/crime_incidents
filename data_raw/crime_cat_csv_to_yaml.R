crime_cat <- read_csv("data_raw/crimeData_offense_codec_categories.csv")

library(yaml)
write_yaml(list(category = split(replace(crime_cat, "codec_category", NULL), crime_cat$codec_category)), 
           "data/crime_categories.yaml")

