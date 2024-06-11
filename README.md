# Cincinnati Crime Incidents

This R code creates the `crime incidents` data resource, which includes crime incidents data from [PDI (Police Data Initiative) Crime Incidents](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Crime-Incidents/k59e-2pvf), and the location and timing of gunshots detected by the shotspotter system. Incidents are the records, of reported crimes, collated by an agency for management. Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. This does not include police calls for service, arrest information, final case determination, or any other incident outcome data. Shotspotter reports are filtered from all [police calls for service](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Police-Calls-for-Servic/gexm-h6bt) that resulted in a police response and had a known location and date.

The "address_x" provided by the city is converted to possible street range lines from the census bureau using text matching for street names and comparison of street number ranges. It is possible for an "address_x" range to have more than one intersection census street range file, which are unionized to one street range geometry. 

Below is a map of the total number of crime incidents and shotspotter reports for each street range approximation.

![crime_incident_map](https://user-images.githubusercontent.com/104022087/214891725-38ae46aa-3872-485a-bc3f-d6d916d19ad9.svg)

Note that in this dataset, each crime incident record is uniquely identified by `INSTANCEID`, but `INCIDENT_NO` may be mapped to multiple `INSTANCEID`. 

A filter is applied to `date-time`, the estimated date/time of the start of the crime, to included crime incidents that occurred on or after January 1, 2011.

Each crime incident is assigned to one of the following categories based on reported `offense`:
* `property` (e.g., burglary, larceny, motor vehicle theft, arson)
* `violent` (e.g., homicide, assault, rape, robbery, domestic violence)
* `other` (e.g., missing/unknown, fraud, identify theft, consensual crime)
* `shotspotter` (number of gunshots)


