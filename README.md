# crime_incidents

This R code creates the `crime incidents` data resource. The crime incidents data are downloaded from [PDI (Police Data Initiative) Crime Incidents](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Crime-Incidents/k59e-2pvf), which are updated daily. This data represents reported crime incidents in the City of Cincinnati. Incidents are the records, of reported crimes, collated by an agency for management. Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. This does not include police calls for service, arrest information, final case determination, or any other incident outcome data.

The "x_address" provided by the city is converted to possible street range lines from the census bureau using text matching for street names and comparison of street number ranges. It is possible for an "x_address" range to have more than one intersection census street range file, which are stored in the `street_ranges` list-col, alongside the `address_x`, `date_time`, `INSTANCEID`, `INCIDENT_NO`, and three offense category columns. 94% (n=332,709) of all 353,449 records were matched to at least one census street range geography.

Below is a map of the total number of crime incidents detected in each street range approximation in Avondale, East Price Hill, and West Price Hill:

![crime_incident_map](https://user-images.githubusercontent.com/104022087/214565758-f71a9123-0f8e-452e-b32c-e73c35ed3bd8.svg)

Note that in this dataset, each crime incident record is uniquely identified by `INSTANCEID`, but `INCIDENT_NO` may be mapped to multiple `INSTANCEID`. 

A filter is applied to `date_time`, the estimated date/time of the start of the crime, to included crime incidents occurred on 1/1/2011 or after.

The following three categoies are assigned to each crime incident based on offense, using indicator variables, `property`, `violent`, `other`.
* property (e.g., burglary, larceny, motor vehicle theft, arson)
* violent (e.g., homicide, assault, rape, robbery, domestic violence)
* other (e.g., missing/unknown, fraud, identify theft, consensual crime)


