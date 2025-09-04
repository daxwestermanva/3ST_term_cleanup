
/* =============================================
-- Author:		Catherine Barry
-- Create date: 6/1/2017
-- Description:	Report dataset for REACH VET metric report.

--Test:
	EXEC [App].[Reach_HistoricMetrics_v02] 'VHA21\VHAPALSTEPHR6','2','2020-04-08','2'

--Modifications:
	--20200130	RAS	Renamed from App.Reach_MetricBasetable_long to Reach_HistoricMetricsBasetable (to match report)
					Pointed to MetricBasetable_long_v02
	--20200527	RAS	Pointed code to new table REACH.MonthlyMetrics_v02
	--20200605	LM	Added benchmark info for underperforming and 100% performing facilities
	--20210112	LM	Added WITH(NOLOCK), formatting
	--20220804	LM	Added total counts of patients identified by REACH VET
-- ============================================= */
CREATE PROCEDURE [App].[Reach_HistoricMetrics]
	 @User varchar(50)
	,@VISN varchar(500)
	,@ReleaseDate varchar(max)
	,@Week varchar(50)

AS
BEGIN
	SET NOCOUNT ON;

--For testing
--DECLARE @User varchar(50),@VISN varchar(500),@ReleaseDate varchar(max),@Week varchar(50)
--SET @User='vha21\vhapalminal'; SET @VISN=22; SET @ReleaseDate='2022-07-13,2020-06-10';SET @Week=2 --should have values 0 or above in benchmark, consecmonths, and count columns
--SET @User='vha16\vhajacmoores1'; SET @VISN=23; SET @ReleaseDate='2020-04-08';SET @Week=2 --should have -1 in benchmark, consecmonths, and count columns
DROP TABLE IF EXISTS #MetricsStage
SELECT DISTINCT a.VISN
	  ,a.ReleaseDate
	  ,a.ChecklistID
	  ,b.Admparent_FCDM
	  ,b.ADMPSortKey
	  ,a.Wk
	  ,a.Metric
	  ,a.Denominator
	  ,a.Numerator
	  ,round(a.Score,2) AS Score
	  ,c.Benchmark
	  ,Score_Benchmark = 
		CASE WHEN a.Wk<>2 THEN 0
			WHEN a.ReleaseDate < '2019-11-01' THEN -1
			WHEN a.Metric='OutreachSucc' AND a.Score >=.795 THEN 1
			WHEN a.Metric='OutreachSucc' THEN 0
			WHEN a.ReleaseDate > '2025-07-01' AND a.Score >=.895 THEN 1
			WHEN a.ReleaseDate BETWEEN '2020-05-01' AND '2025-07-01' AND a.Score >=.945 THEN 1
			WHEN a.ReleaseDate BETWEEN '2019-11-01' and '2020-04-30' AND a.Score >=.895 THEN 1
			WHEN a.Score >=.845 THEN 2 --Yellow
			WHEN a.Score >=.745 THEN 3 --Orange
			WHEN a.Score <.745 THEN 4 --Salmon
			ELSE 0 
			END
	  ,CASE WHEN 
	        --@User IN ('vha19\vhaechmatarb','vha19\vhaechgerarg','vha19\VHAECHGassC','vha11\VHASAGLamonL','vha10\VHACLERotolC','vha22\VHALONPeterT1') 
			--Bridget Matarazzo, Georgia Gerard, Carolyn Gass, Laurie Lamonde, Katie Rotolo, Tiara Peterkin (all from either RM MIRECC or SPP Field Ops)
		    (d.UserName IS NOT NULL OR @User IN 
			(select NetworkId from [Config].[ReportUsers] where project like 'REACH'))
		 
		THEN c.ConsecMonthsUnderperforming
		ELSE -1 END AS ConsecMonthsUnderperforming
	  ,Count=NULL
	  ,MaxReleaseDate=CAST(NULL AS date)
INTO #MetricsStage
FROM [REACH].[MonthlyMetrics] AS a WITH (NOLOCK)
INNER JOIN [LookUp].[ChecklistID] AS b WITH (NOLOCK) 
	ON a.ChecklistID=b.ChecklistID
LEFT JOIN [REACH].[MonthlyMetricBenchmarks] AS c WITH (NOLOCK)
	ON a.ChecklistID=c.ChecklistID 
	AND a.ReleaseDate=c.ReleaseDate 
	AND a.Wk=c.Wk
LEFT JOIN (SELECT * FROM [Config].[WritebackUsersToOmit] WHERE UserName LIKE 'vha21\vhapal%') AS d 
	ON @User=d.UserName
WHERE a.Wk IN (SELECT value FROM string_split(@Week,',')) 
	AND a.VISN IN (SELECT value FROM string_split(@visn,','))
	AND a.ReleaseDate IN (SELECT value FROM string_split(@ReleaseDate,','))
ORDER BY b.ADMPARENT_FCDM
	,a.ReleaseDate

UPDATE #MetricsStage
SET Count =
 (SELECT CASE WHEN ConsecMonthsUnderperforming = -1 THEN -1
		ELSE Count(DISTINCT h.MVIPersonSID) END
	FROM Reach.History h WITH (NOLOCK)
	WHERE h.FirstRVDate BETWEEN '2017-03-01' AND (SELECT max(ReleaseDate) FROM #MetricsStage)
		OR h.MostRecentRVDate BETWEEN '2017-03-01' AND (SELECT max(ReleaseDate) FROM #MetricsStage)
	)

UPDATE #MetricsStage
SET MaxReleaseDate = (SELECT max(ReleaseDate) FROM #MetricsStage)

SELECT * FROM #MetricsStage
END