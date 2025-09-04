
/* =========================================================================================
  Author:  Christina Wade	[logic adapted from of Code.BHIP_MHTC_FollowUp]
  Create date: 12-17-2024
  Description: Derive the 3 most recent BHIP assessments for non-test patients 
			   in the past year.

			   Credited via health factor OR note title.
                 
  Modifications: 
-- 12-18-2024 CW  Swapping data source for VisitSID and VisitDateTime
 =========================================================================================*/
CREATE PROCEDURE [Code].[Present_BHIPAssessments]


AS BEGIN	

	--Get all non-test patients
	DROP TABLE IF EXISTS #Cohort  
	SELECT DISTINCT a.MVIPersonSID, b.PatientPersonSID, b.Sta3n
	INTO #Cohort
	FROM Common.MasterPatient a WITH (NOLOCK)
	INNER JOIN Common.MVIPersonSIDPatientPersonSID b WITH (NOLOCK)
		ON a.MVIPersonSID=b.MVIPersonSID
	WHERE a.TestPatient=0;

	--Find BHIP assessments via health factors
	DROP TABLE IF EXISTS #HF_TypeCategory 
	SELECT a.HealthFactorTypeSID 
		,a.HealthFactorType
		,HealthFactorCategory=b.HealthfactorType
	INTO #HF_TypeCategory
	FROM Dim.HealthFactorType a WITH(NOLOCK)
	LEFT JOIN Dim.HealthFactorType b WITH(NOLOCK)
		ON a.CategoryHealthFactorTypeSID=b.HealthFactorTypeSID
	WHERE a.Entrytype='FACTOR' AND b.Entrytype='CATEGORY'
	-- ONLY INCLUDE INFO FROM THE INTERVENTION AND ASSIGNMENT NOTE
	AND a.HealthFactorType LIKE 'VA-MH-BHIP%'
	-- EXCLUDE THE MHTC ASSIGNMENT NOTE INFO HF CATEGORY = 'VA-MH TX ASSIGNMENT [C]'
	AND b.HealthFactorType IN ('VA-MHTC CCI [C]');

	DROP TABLE IF EXISTS #HealthFactor 
	SELECT DISTINCT ChecklistID=ISNULL(div.ChecklistID,hf.Sta3n)
		,c.MVIPersonSID
		,op.VisitDateTime
		,op.VisitSID
	INTO #HealthFactor
	FROM #Cohort c
	INNER JOIN HF.HealthFactor hf WITH (NOLOCK)
		ON c.PatientPersonSID=hf.PatientSID AND c.Sta3n=hf.Sta3n
	INNER JOIN #HF_TypeCategory hftc
		ON hf.HealthFactorTypeSID=hftc.HealthFactorTypeSID
	INNER JOIN Outpat.Visit op WITH (NOLOCK)
		ON op.VisitSID=hf.VisitSID
	LEFT JOIN LookUp.DivisionFacility div WITH (NOLOCK) 
		ON div.DivisionSID = op.DivisionSID
	WHERE hf.HealthFactorDateTime >= dateadd(day, -366, getdate());

	--Find BHIP assessments via note title
	DROP TABLE IF EXISTS #NoteTitle
	SELECT DISTINCT ChecklistID=ISNULL(div.ChecklistID,d.Sta3n)
		,c.MVIPersonSID
		,op.VisitDateTime
		,op.VisitSID
	INTO #NoteTitle
	FROM #Cohort c
	INNER JOIN TIU.TIUDocument d WITH (NOLOCK)
		ON c.PatientPersonSID=d.PatientSID AND c.Sta3n=d.Sta3n
	INNER JOIN Dim.TIUStatus st WITH (NOLOCK) --Inner join instead?
		ON d.TIUStatusSID=st.TIUStatusSID
	INNER JOIN LookUp.ListMember lm WITH (NOLOCK) 
		ON d.TIUDocumentDefinitionSID = lm.ItemID
	INNER JOIN Outpat.Visit op WITH (NOLOCK) 
		ON d.VisitSID=op.VisitSID
	LEFT JOIN LookUp.DivisionFacility div WITH (NOLOCK)
		ON div.DivisionSID = op.DivisionSID
	WHERE d.EntryDateTime >= dateadd(day, -366, getdate())
	AND lm.AttributeValue LIKE 'MHTC BHIP CC NEEDS ASSESSMENT AND INTERVENTION PLAN'
	AND st.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated'); --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.

	--Combine
	DROP TABLE IF EXISTS #BHIP_Assessment
	SELECT *
	INTO #BHIP_Assessment
	FROM #HealthFactor
	UNION 
	SELECT *
	FROM #NoteTitle;

	--Order the assessments by VisitDateTime
	--Derive the most recent 3 BHIP assessments
	DROP TABLE IF EXISTS #Final
	SELECT *
	INTO #Final
		FROM (
		SELECT *, AssessmentRN=ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY VisitDateTime DESC) 
		FROM #BHIP_Assessment ) Src
	WHERE AssessmentRN <= 3


	EXEC [Maintenance].[PublishTable] 'Present.BHIP_Assessments','#Final'


END