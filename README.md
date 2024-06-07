# Cincinnati Crime Incidents

This R code creates the `crime incidents` data resource. The crime incidents data are downloaded from [PDI (Police Data Initiative) Crime Incidents](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Crime-Incidents/k59e-2pvf), which are updated daily. This data represents reported crime incidents in the City of Cincinnati. Incidents are the records, of reported crimes, collated by an agency for management. Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. This does not include police calls for service, arrest information, final case determination, or any other incident outcome data.

The "ADDRESS_X" provided by the city is converted to possible street range lines from the census bureau using text matching for street names and comparison of street number ranges. It is possible for an "x_address" range to have more than one intersection census street range file, which are unionized to one street range geometry. 83% (n=449,165) of all 538,755 records were matched to at least one census street range geography (n=86,873 missing address; n=12,717 unmatched address).

Below is a map of the total number of crime incidents detected in each street range approximation.

![crime_incident_map](https://user-images.githubusercontent.com/104022087/214891725-38ae46aa-3872-485a-bc3f-d6d916d19ad9.svg)

Note that in this dataset, each crime incident record is uniquely identified by `INSTANCEID`, but `INCIDENT_NO` may be mapped to multiple `INSTANCEID`. 

A filter is applied to `DATE_FROM`, the estimated date/time of the start of the crime, to included crime incidents that occurred on or after January 1, 2011.

Each crime incident is assigned to one of the following categories based on reported `OFFENSE`:
* `property` (e.g., burglary, larceny, motor vehicle theft, arson)
* `violent` (e.g., homicide, assault, rape, robbery, domestic violence)
* `other` (e.g., missing/unknown, fraud, identify theft, consensual crime)


