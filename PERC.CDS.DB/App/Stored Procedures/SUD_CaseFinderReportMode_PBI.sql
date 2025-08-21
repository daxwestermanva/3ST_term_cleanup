-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	1/3/2025
-- Description:	Creating dataset for Power BI report so that all slicers will be generated from one
--				procedure. This will help with overall speed and performance of Power BI report.
--				
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 1/6/2025  CW  Updating SUDType method

--
-- =======================================================================================================
CREATE PROCEDURE [App].[SUD_CaseFinderReportMode_PBI]
AS
BEGIN

	--Slicers: SUD Cohort Selection, DoD Separation
	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT c.MVIPersonSID
		,FullPatientName=CONCAT(mp.PatientName,' (',mp.LastFour,')')
		,DoDSlicer=
			CASE WHEN mp.ServiceSeparationDate <= GETDATE() AND mp.ServiceSeparationDate >= DATEADD(YEAR,-1,CAST(GETDATE() as date)) THEN 'DoD Separation - Past Year' 
					WHEN mp.ServiceSeparationDate IS NULL THEN 'No DoD Separation Date on File'
					ELSE 'DoD Separation - Over Year Ago' END
		,SUDDxSlicer=
			CASE WHEN c.SUDDxPastYear=1 THEN 'Substance Use Disorder - Past Year' 
					WHEN c.SUDDx=1 THEN 'Substance Use Disorder - Past 5 Years'
					ELSE 'Rule / Out Recent Substance Use' END
	INTO #Cohort
	FROM SUD.CaseFinderCohort c WITH (NOLOCK)
	INNER JOIN Common.MasterPatient mp WITH (NOLOCK)
		ON c.MVIPersonSID=mp.MVIPersonSID;

	--Slicers: Team, Provider Name
	DROP TABLE IF EXISTS #ProviderSlicers
	SELECT  
		d.ChecklistID, b.MVIPersonSID, a.Team, a.TeamRole, a.StaffName AS ProviderName
	INTO #ProviderSlicers
	FROM [Present].[Provider_Active] AS a WITH (NOLOCK)
	INNER JOIN SUD.CaseFinderCohort AS b WITH (NOLOCK)
		ON a.MVIPersonSID = b.MVIPersonSID
	INNER JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
		ON a.Sta6a = c.Sta6a
	INNER JOIN [LookUp].[ChecklistID] AS d WITH (NOLOCK)
		ON c.checklistID = d.ChecklistID
	UNION
	SELECT c.ChecklistID
		,a.MVIPersonSID
		,CASE WHEN b.Program = 'VJO' THEN 'Veterans Justice Outreach (VJO)' 
			  WHEN b.Program = 'HCRV' THEN 'Health Care for Re-Entry Veterans (HCRV)'
			  WHEN b.Program = 'HCHV Case Management' THEN 'Health Care for Homeless Veterans (HCHV) Case Management'
			  ELSE b.PROGRAM END AS Program
		,'Lead Case Manager' AS TeamRole
		,b.LeadCaseManager AS ProviderName
	FROM [SUD].[CaseFinderCohort] a WITH (NOLOCK)
	INNER JOIN [PDW].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus] b WITH (NOLOCK)
		ON a.PatientICN = b.PatientICN
	INNER JOIN [Lookup].[ChecklistID] c WITH (NOLOCK)
		ON b.Program_Entry_Sta3n = c.Sta3n;

	--Slicer: Last Mental Health or Primary Care Visit
	DROP TABLE IF EXISTS #Visits
	SELECT DISTINCT
		p.MVIPersonSID
		,VisitDateTime=MAX(VisitDateTime)
	INTO #Visits
	FROM SUD.CaseFinderCohort AS p 
	LEFT JOIN ( SELECT MVIPersonSID, VisitDatetime, ApptCategory
				FROM [Present].[AppointmentsPast] WITH (NOLOCK)
				WHERE (ApptCategory IN ('MHRecent','PCRecent'))
				AND MostRecent_ICN=1) as a
			ON a.MVIPersonSID = p.MVIPersonSID
	GROUP BY p.MVIPersonSID;

	DROP TABLE IF EXISTS #ApptRange
	SELECT MVIPersonSID
		,VisitSlicer
		,VisitSlicerSort=CASE WHEN VisitSlicer='None in Past Year' THEN 1
						 WHEN VisitSlicer='Past 3 Months' THEN 2
						 WHEN VisitSlicer='Past 6 Months' THEN 3
						 WHEN VisitSlicer='Past Year' THEN 4 --changing order
						 END
	INTO #ApptRange
	FROM (
		SELECT MVIPersonSID
			,VisitSlicer=
				CASE WHEN VisitDateTime >= DATEADD(day, -90, GETDATE()) THEN 'Past 3 Months'
					 WHEN VisitDateTime >= DATEADD(day, -180, GETDATE()) THEN 'Past 6 Months'
					 WHEN VisitDateTime >= DATEADD(day, -365, GETDATE()) THEN 'Past Year'
					 ELSE 'None in Past Year' END
		FROM #Visits) Src;

	--Slicer: Substance Use Types
	DROP TABLE IF EXISTS #SUDDx
	SELECT DISTINCT c.MVIPersonSID
	,SUDType=
			CASE WHEN i.AUD=1 THEN 'Alcohol Use'
				 WHEN i.OUD=1 OR i.ICD10Description LIKE '%Opioid%' THEN 'Opioid Use'
				 WHEN i.AmphetamineUseDisorder=1 THEN 'Amphetamine Use'
				 WHEN i.COCNdx=1 THEN 'Cocaine Use'
				 WHEN i.COCNdx=0 AND i.AmphetamineUseDisorder=0 AND i.CocaineUD_AmphUD=1 THEN 'Other Stimulant Use'
				 WHEN i.Cannabis=1 THEN 'Cannabis Use'
				 WHEN i.ICD10Description LIKE '%Sedative, Hypnotic or Anxiolytic%' OR
					  i.ICD10Description LIKE '%Sedative, Hypnotic, or Anxiolytic%' THEN 'Sedative, Hypnotic or Anxiolytic Use'
				 WHEN i.Cannabis=0 AND i.CannabisUD_HallucUD=1 THEN 'Hallucinogen Use'
				 WHEN i.ICD10Description like '%inhalant%' THEN 'Inhalant Use'
				 WHEN i.Nicdx_poss=1 THEN 'Tobacco Use'
				 WHEN i.ICD10Description LIKE '%Other psychoactive%' THEN 'Other Psychoactive Use'
				 ELSE NULL END
		,SUDTypeSort=
			CASE WHEN i.AUD=1 THEN 1
				 WHEN i.OUD=1 OR i.ICD10Description LIKE '%Opioid%' THEN 2
				 WHEN i.AmphetamineUseDisorder=1 THEN 3
				 WHEN i.COCNdx=1 THEN 4
				 WHEN i.COCNdx=0 AND i.AmphetamineUseDisorder=0 AND i.CocaineUD_AmphUD=1 THEN 5
				 WHEN i.Cannabis=1 THEN 6
				 WHEN i.ICD10Description LIKE '%Sedative, Hypnotic or Anxiolytic%' OR
					  i.ICD10Description LIKE '%Sedative, Hypnotic, or Anxiolytic%' THEN 7
				 WHEN i.Cannabis=0 AND i.CannabisUD_HallucUD=1 THEN 8
				 WHEN i.ICD10Description like '%inhalant%' THEN 9
				 WHEN i.Nicdx_poss=1 THEN 10
				 WHEN i.ICD10Description LIKE '%Other psychoactive%' THEN 11
				 ELSE NULL END
	INTO #SUDDx
	FROM SUD.CaseFinderCohort c WITH (NOLOCK)
	INNER JOIN Present.DiagnosisDate dd WITH (NOLOCK)
		ON c.MVIPersonSID=dd.MVIPersonSID
	INNER JOIN LookUp.ICD10 i WITH (NOLOCK)
		ON dd.ICD10Code=i.ICD10Code
	WHERE c.SUDDx=1;

	DROP TABLE IF EXISTS #SUDDx_AdditionalConsiderations
	SELECT DISTINCT d.MVIPersonSID
		,lc.PrintName
		,SUDType=
			CASE WHEN lc.PrintName LIKE '%Alcohol%' THEN 'Alcohol Use'
				 WHEN lc.PrintName LIKE '%Opioid%' THEN 'Opioid Use'
				 WHEN lc.PrintName = 'Cocaine' THEN 'Cocaine Use'
				 WHEN lc.PrintName = 'Non Cocaine Stimulant Use Disorder' THEN 'Other Stimulant Use'
				 WHEN lc.PrintName = 'Cannabis' THEN 'Cannabis Use'
				 WHEN lc.PrintName LIKE '%Sedative%' THEN 'Sedative, Hypnotic or Anxiolytic Use'
				 WHEN lc.PrintName = 'Cannabis/Hallucinogen' THEN 'Hallucinogen Use'
				 ELSE 'Other Psychoactive Use'  END --If not clearly labeled via PrintName, Other Psychoactive Use
		,SUDTypeSort=
			CASE WHEN lc.PrintName LIKE '%Alcohol%' THEN 1
				 WHEN lc.PrintName LIKE '%Opioid%' THEN 2
				 WHEN lc.PrintName = 'Cocaine' THEN 4
				 WHEN lc.PrintName = 'Non Cocaine Stimulant Use Disorder' THEN 5
				 WHEN lc.PrintName = 'Cannabis' THEN 6
				 WHEN lc.PrintName LIKE '%Sedative%' THEN 7
				 WHEN lc.PrintName = 'Cannabis/Hallucinogen' THEN 8
				 ELSE 11 END
	INTO #SUDDx_AdditionalConsiderations
	FROM Present.Diagnosis d WITH (NOLOCK)
	INNER JOIN [LookUp].[ColumnDescriptions] lc WITH (NOLOCK)
		ON d.DxCategory = lc.ColumnName
	WHERE lc.Category='Substance Use Disorder';

	UPDATE #SUDDx 
	SET SUDType=a.SUDType, 
		SUDTypeSort=a.SUDTypeSort
	FROM #SUDDx s
	LEFT JOIN #SUDDx_AdditionalConsiderations a
		On s.MVIPersonSID=a.MVIPersonSID
	WHERE s.SUDType IS NULL;

	--Slicer: SUD Related Risk Factors
	DROP TABLE IF EXISTS #SUDRiskFactors
	SELECT DISTINCT MVIPersonSID, SUDRiskFactorsType=RiskType
	INTO #SUDRiskFactors
	FROM SUD.CaseFinderRisk WITH (NOLOCK)
	WHERE SortKey IN (1,2,3,4,5,6,7,9,10,11,12);

	--Slicer: Suicide & Overdose Behaviors
	DROP TABLE IF EXISTS #SuiOD
	SELECT DISTINCT c.MVIPersonSID, SuicideODType=CASE WHEN SortKey IN (13, 14, 15, 16) THEN 'Overdose - Past Year' ELSE RiskType END
	INTO #SuiOD
	FROM SUD.CaseFinderRisk c WITH (NOLOCK)
	WHERE SortKey IN (8,13,14,15,16,17,18)
	ORDER BY MVIPersonSID;

	--Slicer: Positive Drug Screen
	DROP TABLE IF EXISTS #PositiveResults 
	SELECT DISTINCT c.MVIPersonSID
		,LabGroup=
			CASE WHEN u.LabGroup='Amphetamine' THEN 'Amphetamine'
				 WHEN u.LabGroup='Barbiturate' THEN 'Barbiturate'
				 WHEN u.LabGroup='Benzodiazepine' THEN 'Benzodiazepine'
				 WHEN u.LabGroup='Buprenorphine' THEN 'Buprenorphine'
				 WHEN u.LabGroup='Cannabinoid' THEN 'Cannabinoid'
				 WHEN u.LabGroup='Cocaine' THEN 'Cocaine'
				 WHEN u.LabGroup='Codeine' THEN 'Codeine'
				 WHEN u.LabGroup='Dihydrocodeine' THEN 'Dihydrocodeine'
				 WHEN u.LabGroup='Drug Screen' THEN 'Drug Screen'
				 WHEN u.LabGroup='Ethanol' THEN 'Ethanol'
				 WHEN u.LabGroup='Fentanyl' THEN 'Fentanyl'
				 WHEN u.LabGroup='Heroin' THEN 'Heroin'
				 WHEN u.LabGroup='Hydrocodone' THEN 'Hydrocodone'
				 WHEN u.LabGroup='Hydromorphone' THEN 'Hydromorphone'
				 WHEN u.LabGroup='Ketamine' THEN 'Ketamine'
				 WHEN u.LabGroup='Meprobamate' THEN 'Meprobamate'
				 WHEN u.LabGroup='Methadone' THEN 'Methadone'
				 WHEN u.LabGroup='Morphine' THEN 'Morphine'
				 WHEN u.LabGroup='Other Opiate' THEN 'Other Opiate'
				 WHEN u.LabGroup='Oxycodone' THEN 'Oxycodone'
				 WHEN u.LabGroup='Oxymorphone' THEN 'Oxymorphone'
				 WHEN u.LabGroup='Phencyclidine (PCP)' THEN 'Phencyclidine (PCP)'
				 WHEN u.LabGroup='Tramadol' THEN 'Tramadol' END
	INTO #PositiveResults
	FROM #Cohort c
	INNER JOIN Present.UDSLabResults as u WITH (NOLOCK)
		ON u.MVIPersonSID=c.MVIPersonSID
	WHERE LabScore=1 AND (LabDate >= DATEADD(YEAR, -1, CAST(GETDATE() AS DATE)));

	--Slicer: Current VA Rx / Medication Types
	DROP TABLE IF EXISTS #MedType
	SELECT DISTINCT a.MVIPersonSID
		,MedType= CASE WHEN a.DrugNameWithoutDose LIKE '%BUPRENORPHINE%' THEN 'Buprenorphine'
					 WHEN a.OpioidForPain_rx	= 1 OR a.OpioidAgonist_Rx = 1  THEN 'Opioid'
					 WHEN a.Anxiolytics_Rx = 1 OR a.Benzodiazepine_Rx = 1  THEN 'Anxiolytic or Benzodiazepine'
					 WHEN a.Antidepressant_Rx = 1 THEN 'Antidepressant'
					 WHEN a.Antipsychotic_Rx = 1 THEN 'Antipsychotic'
					 WHEN a.MoodStabilizer_Rx = 1 THEN 'Mood Stabilizer'
					 WHEN a.Stimulant_Rx = 1 THEN 'Stimulant' END
	INTO #MedType
	FROM [Present].[Medications] AS a WITH (NOLOCK) 
	INNER JOIN SUD.CaseFinderCohort as s WITH (NOLOCK)
		ON a.MVIPersonSID = s.MVIPersonSID 
	WHERE Psychotropic_Rx = 1 OR
		Benzodiazepine_Rx = 1 OR
		OpioidForPain_Rx = 1 OR	
		Stimulant_Rx = 1 OR
		OpioidAgonist_Rx = 1 OR 
		a.DrugNameWithoutDose like '%BUPRENORPHINE%';

	--Slicer: Social Drivers
	DROP TABLE IF EXISTS #SDH
	SELECT DISTINCT MVIPersonSID, SDHType=RiskType
	INTO #SDH
	FROM SUD.CaseFinderRisk WITH (NOLOCK)
	WHERE SortKey IN (19,20,21,22);

	--Final table
	--Combine final data with test data (All Mode vs. Demo Mode)
	SELECT DISTINCT c.MVIPersonSID
		,c.FullPatientName
		,c.DoDSlicer
		,c.SUDDxSlicer
		,ChecklistID=sc.ChecklistID
		,VISN
		,Facility=ISNULL(sc.Facility, 'Unassigned')
		,ProviderName=ISNULL(pv.ProviderName,'Unassigned')
		,Team=ISNULL(pv.Team,'Unassigned')
		,f.SUDRiskFactorsType
		,m.MedType
		,s.SUDType
		,s.SUDTypeSort
		,so.SuicideODType
		,sdh.SDHType
		,p.LabGroup
		,a.VisitSlicer
		,a.VisitSlicerSort
		,ReportMode='All Data'
	FROM #Cohort c
	LEFT JOIN #ProviderSlicers pv
		ON c.MVIPersonSID=pv.MVIPersonSID
	LEFT JOIN Present.HomestationMonthly h WITH (NOLOCK)
		ON c.MVIPersonSID=h.MVIPersonSID		
	LEFT JOIN LookUp.ChecklistID sc WITH (NOLOCK)
		ON ISNULL(pv.ChecklistID,h.ChecklistID)=sc.CheckListID
	LEFT JOIN #SUDRiskFactors f
		ON c.MVIPersonSID=f.MVIPersonSID
	LEFT JOIN #SUDDx s
		ON c.MVIPersonSID=s.MVIPersonSID
	LEFT JOIN #SuiOD so
		ON c.MVIPersonSID=so.MVIPersonSID
	LEFT JOIN #SDH sdh
		ON c.MVIPersonSID=sdh.MVIPersonSID
	LEFT JOIN #PositiveResults p
		ON c.MVIPersonSID=p.MVIPersonSID
	LEFT JOIN #MedType m
		ON c.MVIPersonSID=m.MVIPersonSID
	LEFT JOIN #ApptRange a
		ON c.MVIPersonSID=a.MVIPersonSID

	UNION

	--Test patient data
	--ReportMode will be used for Slicer: 'All Data' vs 'Demo Mode'
	--Most recent appointment dates should line up with test patient case statements in [App].[SUD_CaseFinderCohort_PBI]
	SELECT MVIPersonSID
		,FullPatientName
		,DoDSlicer
		,SUDDxSlicer
		,ChecklistID
		,VISN
		,Facility
		,ProviderName
		,TeamName
		,SUDRiskFactorsType
		,MedType
		,SUDType	
		,SUDTypeSort
		,SuicideODType
		,SDHType
		,LabGroup
		,VisitSlicer
		,VisitSlicerSort
		,ReportMode
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)

END