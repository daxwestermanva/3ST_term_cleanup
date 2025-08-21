/********************************************************************************************************************
DESCRIPTION: ReachVet Metrics monthly report - Metrics for Weeks 3 and 4
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
	2019-08-02		RAS		New version to replace Code.Reach_MetricBasetable and Code.Reach_MetricBasetable_long
	2020-06-10		LM		Broke out into separate codes for weeks 1 and 2 metrics
********************************************************************************************************************/

CREATE PROCEDURE [Code].[Reach_MonthlyMetrics_Wk34] 
	(@ForceUpdate BIT = 0
	,@Begin DATE = NULL
	,@END DATE = NULL )
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'Reach_MonthlyMetrics_Wk34','Execution of SP Code.Reach_MonthlyMetrics_Wk34'

--Run Monthly Metrics with parameters to complete month's reporting
DECLARE @BeginDate DATE = DATEADD(d,1,EOMONTH(DATEADD(M,-2,getdate())))
	,@EndDate DATE=EOMONTH(DATEADD(M,-1,getdate()))
EXEC [Code].[Reach_MonthlyMetrics] @BeginDate=@BeginDate,@EndDate=@EndDate,@MaxWeek=4,@MinWeek=3

EXEC [Log].[ExecutionEnd]

END