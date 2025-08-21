-- ===================================================================================
-- Author:		<Amy Robinson>
-- Create date: <2/13/23>
-- Description:	SUD PowerBI - Evidence of IVDU

-- 12-20-2023	CW	Updating EvidenceTypeCount logic
-- 08-07-2024   CW  Adding sort logic-priorities from HHRC
-- 09-18-2024   CW  Adding Emergency Visit and Overdose - Past Year. 
--					Will use this in Harm Reduction Methods & Risk Factors tab of SSP
--					dashboard.
-- 12-30-2024   CW  Adding in Demo patients
--
-- ===================================================================================
CREATE PROCEDURE [App].[SUD_IDUEvidence_PBI]

AS
BEGIN
	SET NOCOUNT ON;

	--------------------------------------------------------------------------
	--Get count of evidence (for use in PBI report)
	--------------------------------------------------------------------------
	DROP TABLE IF EXISTS #EvidenceCount
	SELECT MVIPersonSID,EvidenceTypeCount=SUM(EvidenceTypeCount2)
	INTO #EvidenceCount
	FROM ( SELECT DISTINCT 
				MVIPersonSID
				,EvidenceTypeCount1= --needed for correct sum of evidence
				CASE WHEN EvidenceType='MHA Survey' THEN EvidenceType
						WHEN EvidenceType='SSP Health Factor' THEN EvidenceType
						WHEN EvidenceType='IDU Health Factor' THEN EvidenceType
						WHEN EvidenceType='Harm Reduction Orders' THEN EvidenceType
						WHEN EvidenceType='Drug Screen' THEN EvidenceType
						WHEN EvidenceType='ID Diagnosis' THEN EvidenceType
						WHEN EvidenceType='Note Mentions' THEN EvidenceType
						WHEN EvidenceType='Staph Aureus' THEN EvidenceType
						WHEN EvidenceType='Hep C Labs' THEN EvidenceType
						END
				,EvidenceTypeCount2= --use for summed evidence
				CASE WHEN EvidenceType='MHA Survey' THEN 1
						WHEN EvidenceType='SSP Health Factor' THEN 1
						WHEN EvidenceType='IDU Health Factor' THEN 1
						WHEN EvidenceType='Harm Reduction Orders' THEN 1
						WHEN EvidenceType='Drug Screen' THEN 1
						WHEN EvidenceType='ID Diagnosis' THEN 1
						WHEN EvidenceType='Note Mentions' THEN 1
						WHEN EvidenceType='Staph Aureus' THEN 1
						WHEN EvidenceType='Hep C Labs' THEN 1
						ELSE 0 END
			FROM SUD.IDUEvidence WITH (NOLOCK)) Src
	GROUP BY MVIPersonSID;

	--------------------------------------------------------------------------
	--Additional Risk Factors for use in Harm Reduction Methods & Risk Factors
	--tab (in PBI report)
	--------------------------------------------------------------------------
	--ED visit past year
	DROP TABLE IF EXISTS #ED
	SELECT a.MVIPersonSID, a.ChecklistID, EvidenceDate=VisitDateTime, Details4='ED Visit Past Year'
	INTO #ED
	FROM Present.AppointmentsPast a WITH (NOLOCK)
	INNER JOIN SUD.IDUCohort b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE ApptCategory='EDRecent' AND VisitDateTime > GETDATE() - 365;

	--Overdose past year
	DROP TABLE IF EXISTS #OD
	SELECT DISTINCT a.MVIPersonSID, a.ChecklistID, EvidenceDate=ISNULL(EventDateFormatted,EntryDateTime), Details4='Overdose Past Year'
	INTO #OD
	FROM OMHSP_Standard.SuicideOverdoseEvent a WITH (NOLOCK)
	INNER JOIN SUD.IDUCohort b WITH (NOLOCK) on a.MVIPersonSID=b.MVIPersonSID
	WHERE Overdose=1 AND ISNULL(EventDateFormatted,EntryDateTime) > GETDATE() - 365;

	--Combine additional risk factors 
	DROP TABLE IF EXISTS #AdditionalRisk
	SELECT *
	INTO #AdditionalRisk
	FROM #ED
	UNION
	SELECT *
	FROM #OD

	--------------------------------------------------------------------------
	--Get details for Demo Mode in upstream temp table
	--Change MVIPersonSIDs here to use in below join
	--Further de-identify note snippets to ensure no PHI/PII makes it to the PBI report
	--------------------------------------------------------------------------
	DROP TABLE IF EXISTS #Demo
	SELECT MVIPersonSID=13066049
		,e2.Details
		,Details2=CASE WHEN e2.EvidenceType='Note Mentions' 
			THEN 'to Inpatient Acute Admit to Level of Care: Acute Reason for Admission: ' + '<b>ivdu</b>' + ' complicated abscess Admitting Team: Med 6 Imaging: US DVT, chest and knee xray Meds given: lido 1%, Ceftriaxone Current Infusions: ceftri-vanco to follow Pertinent Abnormal Labs: elevated sed rate Other: ---------------- MRSA: Yes Testing for MRSA' 
			ELSE e2.Details2 END
		,e2.EvidenceType
		,EvidenceTypeCount=4
	INTO #Demo
	FROM (  SELECT TOP (1) a.MVIPersonSID
						FROM SUD.IDUEvidence a WITH (NOLOCK)
						LEFT JOIN #EvidenceCount b on a.MVIPersonSID=b.MVIPersonSID
						WHERE EvidenceTypeCount = 4
					  ) e1
	INNER JOIN SUD.IDUEvidence e2 WITH (NOLOCK) 
		ON e1.MVIPersonSID=e2.MVIPersonSID

	UNION

	SELECT MVIPersonSID=9279280
		,e2.Details
		,Details2=CASE WHEN e2.EvidenceType='Note Mentions' 
			THEN 'the reports being told that he could die if he stopped the medication. Reports that he smokes marijuana when he can get a hold of that and this does help the nausea. Substance abuse/use: - Alcohol: Long-term alcohol use; last use 2015 - Drug use: ' + '<b>ivdu</b>' + ' heroin briefly in 1968. Currently smokes marijuana daily. - Tobacco: Quit 1985 He believes that he was infected with hepatitis B through <b>ivdu</b> in 1968 after he returned from xxxxxxxx; he was despondent because his brother died in xxxxxxxx. ACTIVE PMH:' 
			ELSE e2.Details2 END
		,e2.EvidenceType
		,EvidenceTypeCount=5
	FROM (  SELECT TOP (1) a.MVIPersonSID
						FROM SUD.IDUEvidence a WITH (NOLOCK)
						LEFT JOIN #EvidenceCount b on a.MVIPersonSID=b.MVIPersonSID
						WHERE EvidenceTypeCount = 5
					  ) e1
	INNER JOIN SUD.IDUEvidence e2 WITH (NOLOCK) 
		ON e1.MVIPersonSID=e2.MVIPersonSID

	UNION

	SELECT MVIPersonSID=9415243
		,e2.Details
		,Details2=CASE WHEN e2.EvidenceType='Note Mentions' 
			THEN 'They placed him on the shuttle to send him to his appointment today. He reports a concussion in summer 2022. First tested HCV positive when admitted to XXMC (xxxxxxxx xxxxxxxx Medical Center) for work up of passing out, around 2013. First ' + '<b>ivdu</b>' + ' 2004 after getting back from xxxxxxxx Substance abuse/use: - Alcohol: History of alcohol abuse x 10 years. Reports heavy alcohol use after returning from xxxxxxxx in 2004; currently has a few drinks per month - Drug use: Heroin, cocaine. Drug of choice: '
			ELSE e2.Details2 END
		,e2.EvidenceType
		,EvidenceTypeCount=3
	FROM (  SELECT TOP (1) a.MVIPersonSID
						FROM SUD.IDUEvidence a WITH (NOLOCK)
						LEFT JOIN #EvidenceCount b on a.MVIPersonSID=b.MVIPersonSID
						WHERE EvidenceTypeCount = 3
					  ) e1
	INNER JOIN SUD.IDUEvidence e2 WITH (NOLOCK) 
		ON e1.MVIPersonSID=e2.MVIPersonSID;

	--------------------------------------------------------------------------
	--Final dataset for Power BI
	--------------------------------------------------------------------------
	SELECT ChecklistID
		,a.MVIPersonSID
		,EvidenceType
		,EvidenceDate
		,Details
		,Details2
		,Details3
		,Details4=CASE WHEN Details2='Hepatitis' THEN 'Hepatitis C Dx'
					   WHEN Details2='HIV' THEN 'HIV Dx'
					   WHEN EvidenceType='ID Diagnosis' THEN Details2 
					   WHEN EvidenceType='Staph Aureus' THEN EvidenceType 
					   END
		,Code
		,Facility
		,EvidenceTypeCount
		,EvidenceTypeSort = ROW_NUMBER() OVER
			(	ORDER BY 
					 CASE WHEN EvidenceType = 'SSP Health Factor' THEN 1		--priority sort order 1
						  WHEN EvidenceType = 'Harm Reduction Orders' THEN 2	--priority sort order 2
						  WHEN EvidenceType = 'Hep C Labs' THEN 3				--priority sort order 3
						  WHEN EvidenceType = 'HIV Labs' THEN 4					--priority sort order 4
						  WHEN EvidenceType = 'Staph Aureus' THEN 5				--priority sort order 5
						  WHEN EvidenceType = 'MHA Survey' THEN 6				--priority sort order 6
						  WHEN EvidenceType = 'IDU Health Factor' THEN 7		--priority sort order 7
						  WHEN EvidenceType = 'SUD Engagement' THEN 8			--priority sort order 8
						  WHEN EvidenceType = 'SUD Diagnosis' THEN 9			--priority sort order 9
						  WHEN EvidenceType = 'Note Mentions' THEN 10			--priority sort order 10
						  WHEN EvidenceType = 'Drug Screen' THEN 11				--priority sort order 11
						  WHEN EvidenceType = 'ID Diagnosis' THEN 12			--priority sort order 12
						  END
					,EvidenceDate DESC -- then get most recent records
			 )
		,ReportMode='All Data'
	FROM SUD.IDUEvidence a WITH (NOLOCK)
	LEFT JOIN #EvidenceCount b on a.MVIPersonSID=b.MVIPersonSID
	UNION
	SELECT a.ChecklistID
		,a.MVIPersonSID
		,EvidenceType=NULL
		,EvidenceDate
		,Details=NULL
		,Details2=NULL
		,Details3=NULL
		,a.Details4
		,b.Code
		,b.Facility
		,c.EvidenceTypeCount
		,EvidenceTypeSort=NULL
		,ReportMode='All Data'
	FROM #AdditionalRisk a
	LEFT JOIN LookUp.StationColors b WITH (NOLOCK) on a.ChecklistID=b.CheckListID
	LEFT JOIN #EvidenceCount c on a.MVIPersonSID=c.MVIPersonSID
	UNION
	SELECT ChecklistID
		,mv.MVIPersonSID
		,EvidenceType=e.EvidenceType
		,EvidenceDate=CAST('8/22/1864' as date)
		,Details=e.Details
		,Details2=e.Details2
		,Details3=NULL
		,Details4=NULL
		,Code=NULL
		,Facility=NULL
		,EvidenceTypeCount=e.EvidenceTypeCount
		,EvidenceTypeSort=NULL
		,ReportMode='Demo Mode'
	FROM Common.MasterPatient mv WITH (NOLOCK) 
	INNER JOIN LookUp.ChecklistID c1 WITH (NOLOCK) 
		ON 1=1 and len(c1.ChecklistID) >=3
	INNER JOIN #Demo e
		ON mv.MVIPersonSID=e.MVIPersonSID
	WHERE mv.MVIPersonSID IN (13066049,9279280,9415243);

END