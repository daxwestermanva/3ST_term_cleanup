
-- =============================================
-- Author:		<Liam Mina>
-- Create date: <11/20/2019>
-- Description:	Details about MH Community Status Notes entered for the patient in the past year, based on national health factors
-- Modifications:
-- 2021-09-13	AI:	Enclave Refactoring - Counts confirmed
-- 2022-01-19	LM: Limit to past year
-- =============================================
CREATE PROCEDURE [Code].[Present_CommunityStatusNote]
	
AS
BEGIN

	-- creating view to identify relevant SID's
	DROP TABLE IF EXISTS #HealthFactors;
	SELECT c.Category
		  ,m.List
		  ,m.ItemID
		  ,c.Printname
    INTO #HealthFactors
	FROM [Lookup].[ListMember] m WITH (NOLOCK)
	INNER JOIN [Lookup].[List] c WITH (NOLOCK) ON m.List = c.List
	WHERE c.Category = 'Community Status Note'	
;	

	-- Pulling in data required to expose Suicide Related Health Factors
	DROP TABLE IF EXISTS #PatientHealthFactor; 
	SELECT DISTINCT 
		mvi.MVIPersonSID
		,ChecklistID = ISNULL(z.ChecklistID,h.Sta3n)
		,h.VisitSID 
		,h.HealthFactorSID
		,h.HealthFactorTypeSID
		,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime
		,h.Comments
		,HF.Category
		,HF.List
		,HF.PrintName
	INTO  #PatientHealthFactor
	FROM [HF].[HealthFactor] h
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON h.PatientSID = mvi.PatientPersonSID
	INNER JOIN #HealthFactors HF
		ON HF.ItemID = h.HealthFactorTypeSID
	INNER JOIN [Outpat].[Visit] v WITH (NOLOCK)
		ON h.VisitSID = v.VisitSID
	INNER JOIN [Dim].[Division] dd WITH (NOLOCK)
		ON dd.DivisionSID = v.DivisionSID
	INNER JOIN [Present].[SPatient] b WITH (NOLOCK)
		ON mvi.MVIPersonSID = b.MVIPersonSID
	LEFT JOIN [LookUp].[Sta6a] z WITH (NOLOCK)
		ON dd.sta6a = z.sta6a
	WHERE CAST(HealthFactorDateTime AS date) >= DATEADD(year,-1,CAST(getdate() AS date))
	; 
 
DROP TABLE IF EXISTS #AddRowNumber
SELECT a.*
	,ROW_NUMBER() OVER (PARTITION BY VisitSID ORDER BY Comments, List) AS rn
INTO #AddRowNumber
FROM #PatientHealthFactor a

DROP TABLE IF EXISTS #Final
SELECT a.MVIPersonSID
	,a.ChecklistID
	,a.VisitSID
	,a.HealthFactorDateTime
	,a.PrintName AS Status1
	,b.PrintName AS Status2
	,ISNULL(a.Comments,b.Comments) AS Comments
INTO #Final
FROM (SELECT * FROM #AddRowNumber WHERE rn=1) a
LEFT JOIN (SELECT * FROM #AddRowNumber WHERE rn=2) b ON a.VisitSID=b.VisitSID

DROP TABLE IF EXISTS #FinalRanked
SELECT DISTINCT MVIPersonSID
		  ,ChecklistID
		  ,VisitSID 
		  ,HealthFactorDateTime
		  ,Status1
		  ,Status2
		  ,Comments
		  ,rank() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC) AS MostRecent
		  ,CASE WHEN DateAdd(month,1,CAST(HealthFactorDateTime AS date))>CAST(getdate() AS date) THEN 1 
			ELSE 0 END AS PastOneMonth
		  ,CASE WHEN DateAdd(month,3,CAST(HealthFactorDateTime AS date))>CAST(getdate() AS date) THEN 1 
			ELSE 0 END AS PastThreeMonths
INTO #FinalRanked
FROM #Final

EXEC [Maintenance].[PublishTable] 'Present.CommunityStatusNote', '#FinalRanked'
;

END