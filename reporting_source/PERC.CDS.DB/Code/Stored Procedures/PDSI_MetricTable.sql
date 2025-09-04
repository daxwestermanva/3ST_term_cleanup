
/*
DESCRIPTION: Computes measures for PDSI cohort across all provider and facility groupings. 
	The main table is updated nightly, but once a month the data is added to a trends table.

WRITES TO:
	[PDSI].[MetricTable]

MODIFICATIONS:
	2021-09-16	RAS	Developing original code based on ORM_MetricTable
	2021-11-02	MCP Adding in CM and CBT_SUD metrics
	2021-11-08	RAS	Removed trend snapshot code and table.
	2021-12-10	RAS	Added case statements to account for lower is better measures.
	2022-04-05	MCP Edited CBT_SUD section with new requirements
	2023-11-30	MCP Changed source of CBT-SUD provider counts
	2025-03-20	MCP Adding reviewed patient counts

TESTING:
	EXEC [Code].[PDSI_MetricTable]

TO DO:
	-- Measures CM_Program and CBT_SUD_Provider need to be added to Definitions table in order to appear in parameter selection.


-	Yes, quarterly trends, facility scores and national scores from MHIS
-	Yes for the count of actionable patients with a link to patient report
-	No numerator or denominator
-	Yes count of reviewed patients (from Writeback), but it’s not a priority
-	No provider trendline or scores – Hide the metric score section when something other than stations are chosen and just show # of actionable patients linked to patient report


*/

CREATE PROCEDURE [Code].[PDSI_MetricTable]
AS
BEGIN
EXEC [Log].[ExecutionBegin] @Name = 'Code.PDSI_MetricTable', @Description = 'Execution of Code.PDSI_MetricTable SP'

DROP TABLE IF EXISTS #StagePDSIMetricTable;
CREATE TABLE #StagePDSIMetricTable (
	VISN TINYINT NULL
	,ChecklistID VARCHAR(5) NULL
	,GroupID INT NULL
	,GroupType VARCHAR(25) NULL
	,ProviderSID INT NULL
	,ProviderName VARCHAR(100) NULL
	,MeasureID INT NULL
	,Measure VARCHAR(25) NULL
	,Denominator INT NULL
	,Numerator INT NULL
	,Actionable INT NULL
	,Score DECIMAL(21,3)
	,NatScore DECIMAL(25,14)
	,CM_Numerator INT NULL
	,CBTSUD_Numerator INT NULL
	,MeasureReviewed INT NULL
	)
	-- RAS: Whereas ORM_MetricTable uses ORM.PatientReport, 
		--	for PDSI we need to distill PatientDetails to one row per patient/measure
	DROP TABLE IF EXISTS #PatientMeasure
	SELECT DISTINCT
		p.MVIPersonSID,p.MeasureID,p.Measure,p.MeasureUnmet, p.CM, p.CBTSUD
		,CASE WHEN d.ScoreDirection  = 'Lower is better' THEN 1 ELSE 0 END AS LowerBetter
	INTO #PatientMeasure
	FROM [PDSI].[PatientDetails] p 
	INNER JOIN [PDSI].[Definitions] d ON p.MeasureID=d.MeasureID
	WHERE p.MeasureID>0 -- -1 is used for NULL Measure

--Get reviewed patients/measures
DROP TABLE IF EXISTS #maxwb
SELECT MVIPersonSID
	 ,MAX(rALC_top1) as [ALC_top1]
	 ,MAX(rSUD16) as [SUD16]
	 ,MAX(rSTIMUD1) as [EBP_StimUD]
	 ,MAX(rSTIMRX1) as [STIMRX1]
	 ,MAX(rAPDEM1) as [APDEM1]
	 ,MAX(rAPGLUC1) as [APGLUC1]
	 ,MAX(rCLO1) as [CLO1]
	 ,MAX(rGBENZO1) as [GBENZO1]
	 ,MAX(rOffLabelRxStim) as [Off_Label_RxStim]
	 ,MAX(rCorxRxStim) as [CoRx-RxStim]
	 ,MAX(rNaloxone_StimUD) as [Naloxone_StimUD]
	 ,MAX(rBenzo_PTSD) as [BENZO_PTSD_OP]
	 ,MAX(rBenzo_SUD) as [BENZO_SUD_OP]
	 ,MAX(rBenzo_Opioid) as [BENZO_Opioid_OP]
	 ,MAX(rPDMP_Benzo) as [PDMP_Benzo]
INTO #maxwb
FROM
(SELECT DISTINCT 
	 MVIPersonSID
	,CASE WHEN ActionType like '%ALC_top1%' or actiontype like '%alc_top%' then 1 else 0 end rALC_top1
	,CASE WHEN ActionType like '%SUD16%' then 1 else 0 end rSUD16
	,CASE WHEN ActionType like '%EBP_StimUD%' or ActionType like '%STIMUD1%' then 1 else 0 end rSTIMUD1
	,CASE WHEN ActionType like '%STIMRX1%' or actiontype like '%Monitoring_RxStim%' then 1 else 0 end rSTIMRX1
	,CASE WHEN ActionType like '%APDEM1%' then 1 else 0 end rAPDEM1
	,CASE WHEN ActionType like '%APGLUC1%' then 1 else 0 end rAPGLUC1
	,CASE WHEN ActionType like '%CLO1%' then 1 else 0 end rCLO1
	,CASE WHEN ActionType like '%GBENZO1%' or actiontype like '%Benzo_65_OP%' then 1 else 0 end rGBENZO1
	,CASE WHEN ActionType like '%Off_Label_%' THEN 1 ELSE 0 END rOffLabelRxStim
	,CASE WHEN ActionType like '%Corx-rxstim%' THEN 1 ELSE 0 END rCorxRxStim
	,CASE WHEN ActionType like '%Naloxone_StimUD%' THEN 1 ELSE 0 END rNaloxone_StimUD
	,CASE WHEN ActionType like '%Benzo_PTSD_OP%' THEN 1 ELSE 0 END rBenzo_PTSD
	,CASE WHEN ActionType like '%Benzo_SUD_OP%' THEN 1 ELSE 0 END rBenzo_SUD
	,CASE WHEN ActionType like '%Benzo_Opioid_OP%' THEN 1 ELSE 0 END rBenzo_Opioid
	,CASE WHEN ActionType like '%PDMP_Benzo%' THEN 1 ELSE 0 END rPDMP_Benzo
FROM [PDSI].[Writeback]) a
GROUP BY MVIPersonSID

DROP TABLE IF EXISTS #unpvwb
SELECT MVIPersonSID
	  ,MeasureReviewed
	  ,Flag
	  INTO #unpvwb
FROM (
	SELECT [MVIPersonSID]
		,[ALC_top1]
		,[APDEM1]
		,[APGLUC1]
		,[BENZO_Opioid_OP]
		,[BENZO_PTSD_OP]
		,[BENZO_SUD_OP]
		,[CLO1]
		,[CoRx-RxStim]
		,[EBP_StimUD]
		,[GBENZO1]
		,[Naloxone_StimUD]
		,[Off_Label_RxStim]
		,[PDMP_Benzo]
		,[STIMRX1]
		,[SUD16]
	FROM #maxwb
	) lkup
UNPIVOT (Flag FOR MeasureReviewed IN (
		 [ALC_top1]
		,[APDEM1]
		,[APGLUC1]
		,[BENZO_Opioid_OP]
		,[BENZO_PTSD_OP]
		,[BENZO_SUD_OP]
		,[CLO1]
		,[CoRx-RxStim]
		,[EBP_StimUD]
		,[GBENZO1]
		,[Naloxone_StimUD]
		,[Off_Label_RxStim]
		,[PDMP_Benzo]
		,[STIMRX1]
		,[SUD16]
								   )
	) upvt
WHERE Flag=1

	
	-- Facility Level
	-- We lose patients here who are in PatientDetails, but NOT StationAssignments. Need to fix.
	;WITH Facility AS (
		SELECT DISTINCT
			Locations AS ChecklistID
			,MVIPersonSID
		FROM [PDSI].[PatientDetails]
		WHERE Locations IS NOT NULL
		)
	INSERT INTO #StagePDSIMetricTable (VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID,Measure,Denominator,Numerator,Actionable,Score,CM_Numerator,CBTSUD_Numerator,MeasureReviewed)
	SELECT VISN
		,ChecklistID
		,GroupID = 0
		,GroupType = 'All Provider Groups'
		,ProviderSID = 0
		,ProviderName = 'All Providers'
		,MeasureID,Measure,Denominator,Numerator,Actionable
		,Numerator/CAST(Denominator AS DECIMAL) AS Score
		,CM_Numerator,CBTSUD_Numerator
		,MeasureReviewed
	FROM (
		SELECT ISNULL(cl.VISN ,'0') as VISN
			,CASE WHEN f.ChecklistID IS NULL AND cl.VISN IS NULL THEN '0'
					WHEN f.ChecklistID IS NULL THEN CAST(cl.VISN as VARCHAR)
					ELSE f.ChecklistID END as ChecklistID
			,pm.MeasureID
			,MAX(pm.Measure) as Measure
			,COUNT(DISTINCT pm.MVIPersonSID) as Denominator
			,CASE WHEN MAX(LowerBetter) = 1
				THEN COUNT(DISTINCT (CASE WHEN MeasureUnmet = 1 THEN pm.MVIPersonSID END)) 
				ELSE COUNT(DISTINCT (CASE WHEN MeasureUnmet = 0 THEN pm.MVIPersonSID END)) 
				END as Numerator
			,COUNT(DISTINCT (CASE WHEN MeasureUnmet = 1 THEN pm.MVIPersonSID END)) as Actionable
			,COUNT(DISTINCT (CASE WHEN CM = 1 THEN pm.MVIPersonSID END)) as CM_Numerator
			,COUNT(DISTINCT (CASE WHEN CBTSUD = 1 THEN pm.MVIPersonSID END)) as CBTSUD_Numerator
			,COUNT(DISTINCT (wb.MVIPersonSID)) as MeasureReviewed
		FROM Facility f 
		INNER JOIN #PatientMeasure pm ON pm.MVIPersonSID = f.MVIPersonSID
		INNER JOIN [LookUp].[ChecklistID] cl ON cl.ChecklistID = f.ChecklistID
		LEFT JOIN #unpvwb wb ON pm.MVIPersonSID = wb.MVIPersonSID and pm.Measure = wb.MeasureReviewed
		GROUP BY GROUPING SETS (
			 (cl.VISN,f.ChecklistID,pm.MeasureID)
			,(cl.VISN,pm.MeasureID) -- VISN
			,(pm.MeasureID) -- National
			)
		) a


--Add CBT_SUD score info 
----Use SUD patients as denominator, CBT-SUD Provider counts from Psychotherapy Office Table and score should display as 1/xxx in .rdl
DROP TABLE IF EXISTS #CBTSUD

SELECT COUNT(DISTINCT ProviderSID) AS ProviderCount
	  ,Sta3n 
INTO #CBTSUD
FROM [PDW].[OMHO_EBPTraining_DOEx_EBP_ProviderTrainings] 
WHERE Training_Type = 'CBT-SUD'
GROUP BY Sta3n

	INSERT INTO #StagePDSIMetricTable (VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID,Measure,Denominator,Numerator,Score)
	SELECT a.VISN
		  ,a.ChecklistID
		  ,a.GroupID
		  ,a.GroupType
		  ,a.ProviderSID
		  ,a.ProviderName
		  ,MeasureID = '5160'
		  ,Measure = 'CBT_SUD_Provider'
		  ,a.Denominator
		  ,b.ProviderCount as Numerator
		  ,a.Denominator/NULLIF(b.ProviderCount,0) AS Score
		FROM #StagePDSIMetricTable a
		INNER JOIN [LookUp].[ChecklistID] c ON a.ChecklistID = c.ChecklistID
		INNER JOIN #CBTSUD b ON c.STA3N = b.Sta3n
		WHERE MeasureID = 5155 --uses Benzo_SUD_OP denominator

	UPDATE #StagePDSIMetricTable
	SET NatScore = n.Score
	FROM #StagePDSIMetricTable a
	INNER JOIN (
		SELECT * FROM #StagePDSIMetricTable 
		WHERE VISN = 0
		) n ON n.MeasureID = a.MeasureID

-----------------------------------------------
-- ROLL UP TO PROVIDER LEVEL
-----------------------------------------------
	-- Get each patient and measure with all possible groupings
	DROP TABLE IF EXISTS #PatientReport_GroupAssignments;
	SELECT ga.GroupID
		,ga.GroupType
		,ga.ProviderSID
		,ga.ProviderName
		,ga.ChecklistID
		,ga.VISN
		,pd.MVIPersonSID
		,pd.MeasureID
		,pd.Measure
		,pd.MeasureUnmet
		,pd.LowerBetter
	INTO #PatientReport_GroupAssignments
	FROM #PatientMeasure pd
	INNER JOIN [Present].[GroupAssignments_PDSI] ga ON pd.MVIPersonSID=ga.MVIPersonSID

	-- Compute measure numerator and denominator for each provider
	INSERT INTO #StagePDSIMetricTable (VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID,Measure,Denominator,Numerator,Actionable,Score)
	SELECT VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID,Measure,Denominator,Numerator,Actionable
		,Numerator/CAST(Denominator AS DECIMAL) AS Score
	FROM (
		SELECT 
			VISN
			,ChecklistID
			,GroupID
			,GroupType
			,ProviderSID
			,ProviderName
			,MeasureID
			,MAX(Measure) Measure
			,SUM(MeasureUnmet) as Actionable
			,COUNT(MVIPersonSID) as Denominator
			,CASE WHEN MAX(LowerBetter) = 1
				THEN SUM(MeasureUnmet)
				ELSE COUNT(MeasureUnmet) - SUM(MeasureUnmet)
				END as Numerator
		FROM #PatientReport_GroupAssignments
		GROUP BY VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID -- by provider
		) m 
	
----------------------------------------------------------------------------------
-- Get CM data (only Facility level)
----------------------------------------------------------------------------------
INSERT INTO #StagePDSIMetricTable (VISN,ChecklistID,GroupID,GroupType,ProviderSID,ProviderName,MeasureID,Measure,Denominator,Numerator,Score) --,NatScore
SELECT cl.VISN
	  ,cl.ChecklistID
	  ,GroupID = 0
	  ,GroupType = 'All Provider Groups'
	  ,ProviderSID = 0
	  ,ProviderName = 'All Providers'
	  ,MeasureID = '5159'
	  ,Measure = 'CM_Program'
	  ,Denominator = 1
	  ,CASE WHEN p.[CM_Prog_Status] = 1 THEN 1 ELSE 0 END Numerator
	  ,(p.[CM_Prog_Status]/1) AS Score
FROM [PDSI].[CM_Status] p
INNER JOIN [LookUp].[ChecklistID] cl WITH (NOLOCK) ON p.ChecklistID = cl.ChecklistID

-----------------------------------------------------------------------------------

EXEC [Maintenance].[PublishTable] 'PDSI.MetricTable','#StagePDSIMetricTable'

EXEC [Log].[ExecutionEnd]

END
GO
