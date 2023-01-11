# crime_incidents

This R code creates the crime incidents data resource. The crime incidents data are downloaded from [PDI (Police Data Initiative) Crime Incidents](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Crime-Incidents/k59e-2pvf), which are updated daily. This data represents reported crime incidents in the City of Cincinnati. Incidents are the records, of reported crimes, collated by an agency for management. Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. This does not include police calls for service, arrest information, final case determination, or any other incident outcome data.

Each "INCIDENT_NO" may be mapped to multiple "INSTANCEID", "OFFENSE", "TOTALNUMBERVICTIMS", or "TOTALSUSPECTS". If an incidents include more than one victim or suspect, each row corresponds to one victim or suspect.

A filter is applied to "DATE_FROM", the estimated date/time of the start of the crime, to included crime incidents occurred on 1/1/2011 or after.

The "codec_category" shows crime incidents categories grouped based on offense. There are three categories, including:
* property (e.g., burglary, larceny, motor vehicle theft, arson)
* violent (e.g., homicide, assault, rape, robbery, domestic violence)
* other (e.g., missing/unknown, fraud, identify theft, consensual crime)

The "x_address" provided by the city is converted to possible street range lines from the census bureau using text matching for street names and comparison of street number ranges. It is possible for an "x_address" range to have more than one intersection census street range file, which are stored in the street_ranges list-col, alongside other columns.
