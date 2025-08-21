
/********************************************************************************************************************
DESCRIPTION: Status dataset for SSRSMonitoringReport and SSRSMonitoringLastAccess
TEST:
	EXEC [App].[Monitoring_SSRSStatus] 'Production', '(null)', 'SP'
UPDATE:
	2019-09-30	RAS	Created new SP from Justin's embedded code in report SSRSMonitoringReport
	2020-02-12	LM Changed @GroupName from varchar(55) to varchar(200)
	2021-07-16  EC Removed unneccessary fields ReportName; parameters ReportLocation
	2022-06-08	LM Added Environment parameter
********************************************************************************************************************/

CREATE PROCEDURE [App].[Monitoring_SSRSStatus]
	 @GroupName VARCHAR(200)
	,@Environment VARCHAR (50)
	,@ObjectFileName VARCHAR(55) 

AS
BEGIN
SET NOCOUNT ON

DECLARE @Groups TABLE (GroupName VARCHAR(200))
  -- Add values to the table
INSERT @Groups SELECT value FROM string_split(@GroupName, ',')

SELECT ObjectFileName
	  ,ObjectPath
	  ,Environment
	  ,ReportLocation
	  ,st.GroupName
	  ,LastDayAccessed
	  ,HitCount
	  ,UserCount
	  ,SuccessRate
	  ,HitTotalCount
	  ,UserTotalCount
	  ,TimeDataRetrievalDayAvg
	  ,TimeDataRetrievalAvg						
	  ,TimeDataRetrievalProjected
	  ,TimeDataRetrievalProjectedDeviation
	  ,TimeDataRetrievalStandardDeviation
	  ,TimeDataRetrievalStandardDeviationDelta
	  ,TimeProcessingDayAvg
	  ,TimeProcessingAvg
	  ,TimeProcessingProjected
	  ,TimeProcessingProjectedDeviation
	  ,TimeProcessingStandardDeviation
	  ,TimeProcessingStandardDeviationDelta
	  ,TimeRenderingDayAvg
	  ,TimeRenderingAvg
	  ,TimeRenderingProjected
	  ,TimeRenderingProjectedDeviation
	  ,TimeRenderingStandardDeviation
	  ,TimeRenderingStandardDeviationDelta
	  ,RuntimeDayAvg
	  ,RuntimeAvg
	  ,RuntimeProjected
	  ,RuntimeProjectedDeviation
	  ,RuntimeStandardDeviation
	  ,RuntimeStandardDeviationDelta
FROM [Maintenance].[MonitoringSSRSStatus] st
INNER JOIN @Groups g on g.GroupName=st.GroupName
WHERE (ObjectFileName = @ObjectFileName or @ObjectFileName IS NULL)
AND Environment = @Environment

END