******************************************************************************;
*                          SQL CASE STUDY                                    *;
******************************************************************************;

/* Business Problem */
/* The Transportation Security Administration (TSA) is an agency of the United States Department of
Homeland Security that has authority over the security of the traveling public. Passengers file claims
for injury or property loss or damage that could happen at an airport screening process.
Prepare and analyze TSA Airport Claims and Enplanement data from 2013 through
2017. After preparing the tables, output results to answer business questions. */

/* Deliverables
Here are the three deliverables that are to be completed by the end of the case study:
1. Work.Claims_Cleaned - New table that contains the cleaned and prepared data from the
claimsraw table
2. Work.ClaimsByAirport - New table created by summarizing claims for each airport and year
from work.claims_Cleaned and then joining the summarized data with
enplanement (enplanement2017, boarding2013_2016)
3. FinalReport.html - final HTML report produced by running the ReportProgram.sas
program on the prepared tables */
**********************************************************************************************
;
options nodate;
ods pdf file = '~/certpractice_sql/caseStudy/1_Explore,Prepare_Data_Output.pdf';

/* Access and Explore Data */;


* 1. Define a library to read in tables from data folder;
libname cs '~/certpractice_sql/data/case_study';

* 2. Preview first 10 rows of each table;
title 'cs.claimsraw';
proc print data = cs.claimsraw (obs=10);
run;

title 'cs.enplanement2017';
proc print data = cs.enplanement2017 (obs=10);
run;

title 'cs.boarding2013_2016';
proc print data = cs.boarding2013_2016 (obs=10);
run;
title;

* 3. Generate a report that lists the name, type, and length for each column in all three tables
to determine whether the common columns have any mismatched attributes.;
title 'Report on column name, type, and length';
proc sql number;
	SELECT memname label = 'Table_name', 
		   name label = 'Column_name',
		   type,
		   length
	FROM dictionary.columns
	WHERE LOWCASE(libname) = 'cs'
	AND LOWCASE(memname) IN ('claimsraw', 'enplanement2017','boarding2013_2016');
quit;
title;

* Data type mismatch:
* Year (num, chr): cs.boarding2013_2016, cs.enplanement2017;

* 4. Check distinct values of chr columns to determine
whether any adjustments are needed.;
proc sql number;
	SELECT DISTINCT claim_site
	FROM cs.claimsraw;
	SELECT DISTINCT disposition
	FROM cs.claimsraw;
	SELECT DISTINCT claim_type
	FROM cs.claimsraw;
run;


* Issue:
* All missing values should be considered 'Unknown';
* Mispelled categories. 

* 5. Explore distinct years;
proc sql number;
	SELECT DISTINCT year(date_received) AS date_received
	FROM cs.claimsraw;
	SELECT DISTINCT year(incident_date) AS incident_date
	FROM cs.claimsraw;
quit;

* 6. Explore claims that break the date order;
* Issue: Incident_date should always occur before Date_received.;
title 'Count claims where the incident date occured after received date';
proc sql number;
	SELECT COUNT(*) AS count_date_issues
	FROM cs.claimsraw
	WHERE incident_date > date_received;
quit;
title;

* 7. Report 'Claims where the incident date occured after received date';
title 'Claims where the incident date occured after received date';
proc sql number;
	SELECT *
	FROM cs.claimsraw
	WHERE incident_date > date_received;
quit;
title;

/* Prepare Data */
* 8. Create a new table that removes entirely duplicated rows.;
proc sql;
	CREATE TABLE Claims_NoDup AS
	SELECT DISTINCT * 
	FROM cs.claimsraw;
quit;

* 9. Create a new table for clean columns;
* 10. Modify the query to fix the 65 date issues
in which incident_date occurs after date_received
by replacing the year 2017 with 2018 in the date_received column;
* 11. Modify the query to replace missing values in Airport_Code with 'Unknown';
* 12. Modify the query to replace missing values in Claim_Type with 'Unknown'
and fix categories.
* 13. Modify the query to replace missing values in Claim_Site with 'Unknown'
* 14. Modify the query to replace missing values in Disposition with 'Unknown' 
and fix categories.;
* 15. Modify the query to select the Close_Amount, State, StateName,
County, and City columns. Format Close_Amount with the DOLLAR format. Include two
decimal places. Convert all State values to uppercase. Convert all StateName, County, and
City values to proper case. Label the Close_Amount and StateName columns as two words
with no underscores;
* 16. Modify the query in the previous step to include only those rows where Incident_Date is
between 2013 and 2017. Order the results by Airport_Code and Incident_Date. ;
proc sql;
	CREATE TABLE cs.Claims_Cleaned AS
	SELECT claim_number label='Claim Number',
		   incident_date label = 'Incident Date',
		CASE WHEN incident_date > date_received THEN intnx('year', date_received, 1,'sameday')
		   ELSE date_received 
		   END AS date_received label = 'Date Received' format=date9.,
		CASE WHEN airport_code IS NULL THEN 'Unknown'
		   ELSE airport_code
		   END AS airport_code label = 'Airport Code',
		   airport_name label = 'Airport Name',
		CASE WHEN claim_type IS NULL THEN 'Unknown'
		   WHEN claim_type LIKE "%/%" THEN SCAN(claim_type, 1, "/")
		   ELSE claim_type
		   END AS claim_type label = 'Claim Type',	
		CASE WHEN claim_site IS NULL THEN 'Unknown'
		   ELSE claim_site
		   END AS claim_site label = 'Claim Site',
		CASE WHEN disposition IS NULL THEN 'Unknown'
		   WHEN STRIP(SCAN(disposition,1,':')) = "losed" THEN "Closed:Contractor Claim"
		   WHEN PRXMATCH('/: Canceled/', disposition) > 0 THEN "Closed:Canceled"
		   ELSE disposition
		   END AS disposition label = 'Disposition',
		close_amount format = dollar12.2 label = 'Close Amount',
		upcase(state) AS state,
		propcase(statename) AS statename label = 'State Name',
		propcase(county) AS county, 
		propcase(city) AS city
	FROM Claims_NoDup
	WHERE year(incident_date) BETWEEN 2013 AND 2017
	ORDER BY airport_code, incident_date;
quit;

proc freq data=cs.claims_cleaned nlevels;
	table claim_type /missing list;
	table claim_site /missing list;
	table disposition / missing list;
run;

* 17. Use the work.Claims_Cleaned table to create a view named TotalClaims to count the number
of claims for each value of Airport_Code and Year. Include the columns Airport_Code,
Airport_Name, City, State, the year of Incident_Date, and the new count as TotalClaims.;
title 'View: Count claims by Airport Code and Year';
proc sql;
	CREATE VIEW TotalClaims AS
	SELECT Airport_Code,
		   Airport_Name,
		   City,
		   State,
		   Year(incident_date) AS Year,
		   count(*) AS TotalClaims
	FROM cs.Claims_Cleaned
	GROUP BY airport_code, 
			 airport_name,
			 city,
			 state,
			 year
	ORDER BY airport_code, year;
quit;
title;

* 18. Create a view named TotalEnplanements by using the OUTER UNION set operator to
concatenate the enplanement2017;
title 'View: Total Enplanements';
proc sql;
	CREATE VIEW TotalEnplanements AS 
	SELECT LocID,
		   Enplanement,
		   input(Year, 4.) AS Year /*change to numeric*/
	FROM cs.enplanement2017
	OUTER UNION CORRESPONDING
	SELECT LocID,
		   Boarding as Enplanement,
		   Year
	FROM cs.boarding2013_2016
	ORDER BY Year, LocID;
quit;

* 19. Create a table named ClaimsByAirport by joining the TotalClaims and TotalEnplanements
views on Airport_Code and Year. Include the columns Airport_Code, Airport_Name, City,
State, Year, TotalClaims, and Enplanement. Create a new column named PctClaims that
contains TotalClaims divided by Enplanement. Order the table by Airport_Code and Year;
proc sql;
	CREATE TABLE cs.ClaimsByAirport AS 
	SELECT c.airport_code,
		   c.airport_name,
		   c.city,
		   c.state,
		   c.year,
		   c.totalclaims,
		   e.enplanement,
		   (c.TotalClaims / e.Enplanement) AS PctClaims
	FROM TotalClaims AS c
		INNER JOIN TotalEnplanements AS e
		ON c.airport_code = e.locid 
		AND c.year = e.year
	ORDER BY c.airport_code, c.year;
quit;

/* Analyze and Report on Data */
* 20. How many total enplanements occurred?;
title 'Total Enplanements';
proc sql;
	SELECT SUM(enplanement) AS Totalenplanements format=comma14.
	FROM TotalEnplanements;
quit;

* 21. How many total claims were filed?;
title 'Total Claims filed';
proc sql;
	SELECT SUM(TotalClaims) AS TotalClaims format=comma14.
	FROM TotalClaims;
quit;

* 22. What is the average time in days to file a claim? (from incident_date to date_received);
title 'Average time in days to file a claim';
proc sql;
	SELECT AVG(INTCK('day', incident_date, date_received)) AS avg_days format=8.1
	FROM cs.claims_cleaned;
quit;

* 23. How many unknown airport codes are in the results?;
title 'Number of Unknown airport codes';
proc sql;
	SELECT COUNT(airport_code)
	FROM cs.claims_cleaned
	WHERE airport_code like 'Unk%';
quit;

* 24. What type of claim occurs most frequently? How many claims were that type?;
title 'Claim type counts';
proc sql;
	SELECT claim_type, 
		   COUNT(claim_type) AS count format=comma14.
	FROM cs.claims_cleaned
	GROUP BY claim_type
	ORDER BY count DESC;
quit;

* 25. How many claims include the term Closed?;
title "Claims that were 'Closed'";
proc sql;
	SELECT disposition,
		   COUNT(*) AS count,
		   (SELECT COUNT(*) 
		   FROM cs.claims_cleaned
		   WHERE lowcase(disposition) LIKE '%closed%') AS total
	FROM cs.claims_cleaned
	WHERE lowcase(disposition) LIKE '%closed%'
	GROUP BY disposition;
quit;

* 26. Among airports with over 10 million annual passengers, which airport and year had the highest
percentage of claims filed?;
title 'Airport and years with highest percentage of claims filed from airports with 10M+ annual passengers';
proc sql outobs=1;
	SELECT airport_code,
		   airport_name,
		   year,
		   pctclaims
	FROM cs.claimsbyairport
	WHERE enplanement > 10000000
	ORDER BY pctclaims DESC;
quit;

* 27. Top 20 Airports by Percent Claims with over 10M+ passengers;
title 'Top 20 Airports with Percent Claims with over 10M+ passengers';
proc sql outobs=20 number;
	SELECT *
	FROM cs.claimsbyairport
	WHERE Enplanement > 10000000
	ORDER BY PctClaims DESC;
quit;

* 28. Total Claims by year;
title 'Total Claims by year';
proc sql;
	SELECT put(Incident_Date, year4.) as Year,
       count(*) as TotalClaims format=comma16.
    FROM cs.claims_cleaned
    GROUP BY calculated Year
    ORDER BY Year;
quit;


ods pdf close;
