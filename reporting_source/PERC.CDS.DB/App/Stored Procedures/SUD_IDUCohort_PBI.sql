-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <2/13/23>
-- Description:	SUD PowerBI - Patients with evidence of IVDU

-- 11-14-2023	CW	Updating cohort criteria for PBI report
-- 07-25-2024   CW  Adding PatientSSN for Oracle sites
-- 11-14-2024   CW  Adding No SUD Engagement - Past 6 months to PBI slicers
-- 12-30-2024   CW  Adding in Demo patients
-- 02-13-2024   CW  Changing criteria for Risk Factor slicer re: Hep C
-- 07-24-2025   CW  Adding PatientICN for drill into SSRS reports
-- =============================================
CREATE   PROCEDURE [App].[SUD_IDUCohort_PBI]

AS
BEGIN
	SET NOCOUNT ON;

	----------------------------------
	--Dynamic text for PBI measures 
	----------------------------------
	DROP TABLE IF EXISTS #IDVUCohort 
	select DISTINCT MVIPersonSID, PatientName, LastFour, DateOfBirth, Confirmed, ChecklistID, SUDDx,
	case when Confirmed= 0 then 'NEEDS REVIEW - Possible IDU' 
		 when Confirmed= 1 then 'Confirmed IDU'
		 when Confirmed=-1 then 'Reviewed - Removed by User'
		 else NULL end ConfirmedLabel,
	case when Confirmed= 0 then 1
		 when Confirmed= 1 then 2
		 when Confirmed=-1 then 3
		 else NULL end ConfirmedLabelSort,
	case when Confirmed= 0 then 'Review evidential case factors below - Confirm/Remove'
		 when Confirmed= 1 then 'Confirmed by evidential case factors - Review below'
		 when Confirmed=-1 then 'Reviewed - Removed by User'
		 else NULL end as ConfirmedInstruction
	INTO #IDVUCohort
	from SUD.IDUCohort WITH (NOLOCK);

	----------------------------------
	--Risk factors for PBI slicers
	----------------------------------
	DROP TABLE IF EXISTS #CohortType 
	SELECT DISTINCT MVIPersonSID, CohortType='No PrEP - Past 6 months'
	INTO #CohortType
	FROM [SUD].IDUCohort WITH (NOLOCK)
	WHERE Prep='No'

	UNION ALL
	
	SELECT DISTINCT MVIPersonSID, CohortType='No Fentanyl TS - Past 6 months'
	FROM [SUD].IDUCohort WITH (NOLOCK)
	WHERE FentanylTS='No'

	UNION ALL

	SELECT DISTINCT MVIPersonSID, CohortType='No Naloxone - Past 6 months'
	FROM [SUD].IDUCohort WITH (NOLOCK)
	WHERE Naloxone='No'

	UNION ALL

	SELECT DISTINCT c.MVIPersonSID, CohortType='HIV Dx'
	FROM [SUD].IDUCohort c WITH (NOLOCK)
	INNER JOIN SUD.IDUEvidence e on c.MVIPersonSID=e.MVIPersonSID
	WHERE e.Details2='HIV'

	UNION ALL

	SELECT DISTINCT c.MVIPersonSID, CohortType='Detectable HCV VL'
	FROM [SUD].IDUCohort c WITH (NOLOCK)
	WHERE c.ActiveHepVL='Yes'

	UNION ALL

	SELECT DISTINCT MVIPersonSID, CohortType='Homeless'
	FROM [SUD].IDUCohort WITH (NOLOCK)
	WHERE Homeless=1

	UNION ALL

	SELECT DISTINCT MVIPersonSID, CohortType='No SSP - Past 6 months'
	FROM [SUD].IDUCohort WITH (NOLOCK)
	WHERE InSSP='Uses SSP: NO'

	UNION ALL

	SELECT DISTINCT c.MVIPersonSID, CohortType='No SUD Engagement - Past 6 months'
	FROM [SUD].IDUCohort c WITH (NOLOCK)
	INNER JOIN SUD.IDUEvidence e on c.MVIPersonSID=e.MVIPersonSID
	WHERE e.EvidenceType='SUD Engagement' AND (CAST(e.EvidenceDate AS DATE) < DATEADD(d,-180,GETDATE()) OR e.EvidenceDate IS NULL);

	----------------------------------
	--Final table
	----------------------------------
	DROP TABLE IF EXISTS #CohortFinal
	SELECT i.*, r.CohortType
	INTO #CohortFinal
	FROM #IDVUCohort i
	LEFT JOIN #CohortType r on i.MVIPersonSID=r.MVIPersonSID;


	--Adding in Demo patients and writeback information
	SELECT c.MVIPersonSID
		,m.PatientICN
		,c.PatientName
		,c.LastFour
		,c.DateOfBirth
		,c.Confirmed
		,c.ChecklistID
		,c.SUDDx
		,c.ConfirmedLabel
		,c.ConfirmedLabelSort
		,c.ConfirmedInstruction
		,c.CohortType
		,m.patientSSN
		,Execution_Date=ExecutionDate
		,ExecutionDate=cast(w.ExecutionDate as varchar)
		,w.UserID
		,ReportMode='All Data'
	FROM #CohortFinal c
	inner join Common.MasterPatient m WITH (NOLOCK)
		ON c.MVIPersonSID=m.MVIPersonSID
	left join (select MVIPersonSID, ExecutionDate=MAX(ExecutionDate), UserID=MAX(UserID) from SUD.IDU_Writeback group by MVIPersonSID) w 
		on c.MVIPersonSID=w.MVIPersonSID

	UNION

	SELECT mv.MVIPersonSID
		,mv.PatientICN
		,mv.PatientName
		,mv.LastFour
		,DateOfBirth=CAST('8/22/1864' as date)
		,Confirmed=
			CASE WHEN mv.MVIPersonSID=13066049 THEN 0 --Needs Review (demo)
				 WHEN mv.MVIPersonSID=9279280 THEN 1 --Confirmed IDU (demo)
				 WHEN mv.MVIPersonSID=9415243 THEN -1 --Removed (demo)
				 END
		,ChecklistID
		,SUDDx=
			CASE WHEN mv.MVIPersonSID=13066049 THEN 'No SUD Dx' --Needs Review (demo)
				 WHEN mv.MVIPersonSID=9279280 THEN 'SUD Dx' --Confirmed IDU (demo)
				 WHEN mv.MVIPersonSID=9415243 THEN 'No SUD Dx' --Removed (demo)
				 END
		,ConfirmedLabel=
			CASE WHEN mv.MVIPersonSID=13066049 THEN 'NEEDS REVIEW - Possible IDU' --Needs Review (demo)
				 WHEN mv.MVIPersonSID=9279280 THEN 'Confirmed IDU' --Confirmed IDU (demo)
				 WHEN mv.MVIPersonSID=9415243 THEN 'Reviewed - Removed by User' --Removed (demo)
				 END
		,ConfirmedLabelSort=NULL
		,ConfirmedInstruction=NULL
		,CohortType=NULL
		,patientSSN='123456789'
		,Execution_Date=CAST('8/22/1864' as date)
		,ExecutionDate=cast('8/22/1864' as varchar)
		,UserID='ProviderEmail@va.gov'
		,ReportMode='Demo Mode'
		from Common.MasterPatient mv
		inner join LookUp.ChecklistID c1 on 1=1 and len(c1.ChecklistID) >=3
		where MVIPersonSID IN (13066049,9279280,9415243);


END