


-- =============================================
-- Author:		Meenah Paik
-- Create date: 10/12/2021
-- Description: Main dataset for PDSI Summary Report - uses PDSI.MetricTable
--				Adapted from App.ORM_SummaryReport

-- MODIFICATIONS:
	--	2021-10-21	RAS	Added trend data for report spark line display.
	--	2023-08-08	MCP Adjusting source of trend data
	--	2024-09-26	MCP	Removing old metric names
	--	2024-12-02	MCP Adding Phase 6 metrics
	--	2025-03-24	MCP Adding facility reviewed patient counts
	--	2025-08-19	MCP Adjusting prelim data FYQ being pulled in
-- =============================================
CREATE PROCEDURE [App].[PDSI_SummaryReport]
	 @User varchar(100)
	,@Provider nvarchar(max)
	,@Station varchar(255)
	,@Measure varchar(max)
	,@GroupType varchar(20)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	/*
	Declare @User varchar(100)
	Declare @Provider nvarchar(max)
	Declare @Station varchar(255)
	Declare @SSN varchar(100)
	Declare @Measure varchar(max)
	Declare @GroupType varchar(25)

	Set @User = 'vha21\vhapalpaikm'
	Set @Provider = '0'
	Set @Station = '640'
	Set @Measure = '5125,5119,1116,5156,5154,5155,5157,5158,5159,5161,5116,5132,5128,5163'
	Set @GroupType = 0
	Set @SSN = ''
	*/

DROP TABLE IF EXISTS #Summary;
CREATE TABLE #Summary (
	 VISN TINYINT NULL
	,GroupID varchar(5) NULL
	,GroupType varchar(25) NULL
	,ProviderSID int NULL
	,ProviderName varchar(100) NULL
	,Numerator int NULL
	,Denominator int NULL
	,Score decimal(21,3) NULL
	,Actionable int NULL
	,NatScore decimal(25,14) NULL
	,MeasureID int NULL
	,MeasureMnemonic nvarchar(255) NULL
	,VariableName nvarchar(255) NULL
	,MeasureName nvarchar(255) NULL
	,ChecklistID varchar(5) NULL
	,CM_Numerator int NULL
	,CBTSUD_Numerator int NULL
	,ADMParent_FCDM nvarchar(100) NULL
	,FakeGroup tinyint NULL
	,ScoreDirection nvarchar(255) NULL
	,DimensionID float NULL
	,Dimension nvarchar(255) NULL
	,DashboardOrder float NULL
	,FYQ nvarchar(10) NULL
	,TrendScore decimal(21,3) NULL
	,NatTrendScore decimal(21,3) NULL
	,CM_Active_Status bit NULL
	,MeasureReviewed int NULL
	)
	
;WITH TrendDates AS (
	SELECT DISTINCT TOP 4
		FYQ
	FROM [MDS].[MHIS_CombineData]
	WHERE FYQ like 'FY%Q%'
	ORDER BY FYQ desc
	)
INSERT INTO #Summary(VISN,GroupID,GroupType,ProviderSID,ProviderName,Numerator,Denominator,Score,Actionable,NatScore,MeasureID,MeasureMnemonic,VariableName,MeasureName,ChecklistID,CM_Numerator,CBTSUD_Numerator,ADMParent_FCDM,FakeGroup,ScoreDirection,DimensionID,Dimension,DashboardOrder,FYQ,TrendScore,CM_Active_Status,MeasureReviewed)
SELECT mt.VISN
	  ,mt.GroupID
	  ,mt.GroupType
	  ,mt.ProviderSID
	  ,mt.ProviderName
	  ,mt.Numerator
	  ,mt.Denominator
	  ,mt.Score
	  ,mt.Actionable
	  ,mt.NatScore
	  ,mt.MeasureID
	  ,md.MeasureMnemonic
	  ,md.VariableName
	  ,md.Measurename
	  ,mt.ChecklistID
	  ,mt.CM_Numerator
	  ,mt.CBTSUD_Numerator
	  ,cl.ADMParent_FCDM
	  ,FakeGroup=1
	  ,md.ScoreDirection
	  ,md.DimensionID
	  ,md.Dimension
	  ,md.DashboardOrder
	  ,mhis.FYQ
	  ,ISNULL(mhis.Score,-1) as TrendScore
	  ,cm.CM_Active_Status
	  ,mt.MeasureReviewed
FROM [PDSI].[MetricTable] as mt 
INNER JOIN [LookUp].[ChecklistID] cl WITH (NOLOCK) ON cl.ChecklistID = mt.ChecklistID
LEFT JOIN [PDSI].[Definitions] as md on mt.MeasureID=md.MeasureID

LEFT JOIN (
	SELECT m.FYQ
	,CASE WHEN ChecklistID like '596A4' THEN '596' ELSE ChecklistID END AS ChecklistID
	,Score
	,MeasureMnemonic
	,CASE WHEN MeasureMnemonic like 'alc_top1' THEN '5119'  
	 WHEN MeasureMnemonic like 'gbenzo1' THEN '5154'  
	 WHEN MeasureMnemonic like 'benzo_op1' THEN '5156' 
	 WHEN MeasureMnemonic like 'ptsdbenz1' THEN '5125' 
	 WHEN MeasureMnemonic like 'sudbenz1' THEN '5155' 
	 WHEN MeasureMnemonic like 'OEND3' THEN '5158'  
	 WHEN MeasureMnemonic like 'benzo_pdmp1' THEN '5157'  
	 WHEN MeasureMnemonic like 'SUD16' THEN '1116' 
	 WHEN MeasureMnemonic like 'stimud1' THEN '5161'
	 WHEN MeasureMnemonic like 'clo1' THEN '5116'
	 WHEN MeasureMnemonic like 'apgluc1' THEN '5132'
	 WHEN MeasureMnemonic like 'STIMRX1' THEN '5163'
	 WHEN MeasureMnemonic like 'APDEM1' THEN '5128'
	 ELSE '0'
	 END MeasureID
	FROM [MDS].[MHIS_CombineData] m 
	INNER JOIN TrendDates d ON 
		d.FYQ = m.FYQ
	WHERE MeasureMnemonic in ('alc_top1','gbenzo1','benzo_op1','ptsdbenz1','sudbenz1','OEND3','benzo_pdmp1','SUD16','stimud1','clo1','apgluc1','STIMRX1','APDEM1')

	UNION ALL

	SELECT FYQ
	 ,CASE WHEN ChecklistID like '596A4' THEN '596' ELSE ChecklistID END AS ChecklistID
	 ,Score
	 ,MeasureMnemonic
	 ,CASE WHEN MeasureMnemonic like 'APDEM1' THEN '5128'
	  WHEN MeasureMnemonic like 'STIMRX1' THEN '5163'
	  ELSE '0'
	  END MeasureID
	FROM [PDSI].[APDEM1] m
	WHERE FYQ like 'FY24Q4'

	) mhis ON 
	mhis.measureid = mt.MeasureID
	AND (mhis.ChecklistID = mt.ChecklistID
		AND mt.GroupType = 'All Provider Groups'
		)

LEFT JOIN [PDSI].[CM_Status] as cm ON cm.ChecklistID = mt.ChecklistID
WHERE
	md.DimensionID > 3
	AND mt.ChecklistID IN (SELECT value FROM string_split(@Station,','))
	AND md.MeasureID IN (SELECT value FROM string_split(@Measure ,','))
	AND (
		(@GroupType = -5 AND mt.GroupID = 0 AND mt.ProviderSID = 0) 
		OR (
			GroupID IN (SELECT value FROM string_split(@GroupType ,','))
			AND ProviderSID IN (SELECT value FROM string_split(@Provider,','))
			)
		)

	UPDATE #Summary
	SET NatTrendScore = n.Score
	FROM #Summary a
	INNER JOIN (
		SELECT * FROM [MDS].[MHIS_CombineData] 
		WHERE VISN = 0
		) n ON n.MeasureMnemonic = a.MeasureMnemonic AND n.FYQ = a.FYQ
	
	UPDATE #Summary
	SET NatTrendScore = d.Score
	FROM #Summary a
	INNER JOIN (
		SELECT * FROM [PDSI].[APDEM1]
		WHERE VISN = 0
		) d ON d.MeasureMnemonic = a.MeasureMnemonic AND d.FYQ = a.FYQ
--ORDER BY DashboardOrder,fyq

SELECT * from #Summary

END