
CREATE VIEW [Maintenance].[vwMonitoringSSRSLog] 
AS
-----------------------------------------------------------------------------------------------------------------------------------
-- Initial filtering, parsing and grouping of log data.  This table is used in multiple places.
-- Key function is fn_ParseFolderName.  It controls how the monitoring tool classifies Reports into Groups.
--	YYYY/MM/DD	ABC	- Updates
--	2022/06/16	JEB	- Changed source to point to PDW Synynom that points to Core, and add WITH (NOLOCK)
--					  Note, explicit view definiition is required
-----------------------------------------------------------------------------------------------------------------------------------
SELECT ObjectFileName
	  ,ObjectPath
	  ,ReportLocation
	  ,Environment=SUBSTRING(ObjectPath,CHARINDEX('SSRS/',ObjectPath)+5,CHARINDEX('/CDS',ObjectPath)-21)
	  ,Maintenance.fn_ParseFolderName(ObjectPath) AS GroupName
	  ,UserName
	  ,DATEADD(DD, 0, DATEDIFF(DD, 0, TimeStart)) AS Day
	  ,DATEPART(WEEKDAY, TimeStart) AS Weekday
	  ,DATEPART(WEEK, TimeStart) AS Week
	  ,DATEPART(MONTH, TimeStart) AS Month
	  ,DATEPART(YEAR, TimeStart) AS Year
	  ,CASE WHEN MONTH(TimeStart) > 9
	  		THEN YEAR(TimeStart) + 1
	  		ELSE YEAR(TimeStart)
		END AS FiscalYear
	  ,TimeDataRetrieval
	  ,TimeProcessing
	  ,TimeRendering
	  ,ByteCount
	  ,RowsCount
	  ,Status
	  ,CASE WHEN Status = 'rsSuccess'
	  		THEN 1
	  		ELSE 0
		END AS StatusSuccess
FROM [PDW].[BISL_SSRSLog_DOEx_ExecutionLog] WITH (NOLOCK)
WHERE (ObjectPath like 'RVS/OMHSP_PERC/SSRS/Production/CDS/%' AND (UserName NOT IN (SELECT UserName FROM [Config].[WritebackUsersToOmit] WITH (NOLOCK))) -- Remove us from the stats
	OR (ObjectPath like 'RVS/OMHSP_PERC/SSRS/Test/CDS/%'))
	AND ObjectFileName NOT LIKE '%writeback%';  -- Reports only being analyzed