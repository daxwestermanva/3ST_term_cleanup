/* =============================================
-- Author: Rebecca Stephens (RAS)		 
-- Create date: 2018
-- Description:	Subreport with appointment detail for HRF dashboard
-- Modifications:
--	2020-09-16	LM	Pointed to _VM tables
--	2022-05-16	LM	Changed parameter to MVIPersonSID
--	2024-01-16	LM	Added indicator of possible miscoded MH visits from Cerner
--	2024-11-07	LM	Added visits that do not count for metrics with details to explain
--	2025-05-21	LM	Added staff name

 EXEC [App].[PRF_HRS_SubPatientAppts] @MVIPersonSID=3820, @NoPHI=0, @VisitType='0,1,2,3,4,5,6'
   ============================================= */
CREATE PROCEDURE [App].[PRF_HRS_SubPatientAppts]

	@MVIPersonSID INT
	,@VisitType varchar(15)
	,@NoPHI bit

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DECLARE @VisitTypeList TABLE ([HRF_ApptCategory] VARCHAR(5))
INSERT @VisitTypeList  SELECT value FROM string_split(@VisitType, ',')

DROP TABLE IF EXISTS #Visits
SELECT DISTINCT
	op.MVIPersonSID
    ,op.EpisodeBeginDateTime
	,op.EpisodeEndDateTime
	,Active=CASE WHEN op.EpisodeEndDateTime IS NULL THEN 1 ELSE 0 END
	,op.OutpatDateTime
    ,PrimaryStopCodeName = CASE WHEN op.Sta3n=200 THEN op.PrimaryStopCodeName ELSE CONCAT(op.PrimaryStopCodeName,' (',op.PrimaryStopCode,')') END
	,SecondaryStopCodeName = CASE WHEN op.SecondaryStopCode IS NULL THEN NULL
		ELSE CONCAT(op.SecondaryStopCodeName,' (',op.SecondaryStopCode,')') END
    ,AppointmentStatus = CASE WHEN op.HRF_ApptCategory IN (3,5) THEN CONCAT(op.AppointmentStatus,' - ',CONVERT(varchar,op.CancelDateTime,0))
		ELSE  op.AppointmentStatus END
    ,p.OwnerChecklistID
	,ch.VISN AS OwnerVISN
	,op.Sta3n
    ,op.DivisionName
    ,op.ChecklistID
	,op.Location
	,op.StaffName
    ,op.HRF_ApptCategory
	,Inelig_Category = CASE WHEN op.Inelig_Category=1 AND op.Sta3n=200 THEN 'Reason: Workload, CPT Code, Activity Type'
		WHEN op.Inelig_Category=1 THEN 'Reason: Workload, CPT Code, Stop Code'
		WHEN op.Inelig_Category=2 THEN 'Reason: Workload, CPT Code'
		WHEN op.Inelig_Category=3 AND op.Sta3n=200 THEN 'Reason: Workload, Activity Type'
		WHEN op.Inelig_Category=3 THEN 'Reason: Workload, Stop Code'
		WHEN op.Inelig_Category=4 AND op.Sta3n=200 THEN 'Reason: CPT Code, Activity Type'
		WHEN op.Inelig_Category=4 THEN 'Reason: CPT Code, Stop Code'
		WHEN op.Inelig_Category=5 THEN 'Reason: Workload'
		WHEN op.Inelig_Category=6 AND op.Sta3n=200 THEN 'Reason: Activity Type'
		WHEN op.Inelig_Category=6 THEN 'Reason: Stop Code'
		WHEN op.Inelig_Category=7 THEN 'Reason: CPT Code'
		END
	,cm.PatientName
	,cm.LastFour
	,CASE WHEN op.HRF_ApptCategory=0 THEN 'Past Visit Prior to Last Flag Action, Counts for HRF Metrics'
		WHEN op.HRF_ApptCategory = 1 THEN 'Past Visit Since Last Flag Action, Counts for HRF Metrics'
		WHEN op.HRF_ApptCategory=2 THEN 'Future Appointment'
		WHEN op.HRF_ApptCategory=3 THEN 'Cancelled'
		WHEN op.HRF_ApptCategory=4 THEN 'No-Show'
		WHEN op.HRF_ApptCategory=5 THEN 'Future Appointment, Cancelled'
		WHEN op.HRF_ApptCategory=6 THEN 'Past Visit: Does not Count for HRF Metrics'
		END AS ApptCategoryDescription
	,op.CPTCode_Display
	,CASE WHEN v.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END AS PossMissingCernerVisits
INTO #Visits
FROM [PRF_HRS].[OutpatDetail] as op WITH(NOLOCK)
INNER JOIN [Common].[MasterPatient] AS cm WITH(NOLOCK)
	ON op.MVIPersonSID=cm.MVIPersonSID 
INNER JOIN @VisitTypeList vs
	ON op.HRF_ApptCategory=vs.HRF_ApptCategory
INNER JOIN PRF_HRS.PatientReport_v02 p WITH (NOLOCK)
	ON op.MVIPersonSID=p.MVIPersonSID
INNER JOIN Lookup.ChecklistID ch WITH (NOLOCK)
	ON p.OwnerChecklistID=ch.ChecklistID
LEFT JOIN [OracleH_QI].[PossibleMHVisits] v WITH (NOLOCK)
	ON op.MVIPersonSID = v.MVIPersonSID
WHERE op.MVIPersonSID=@MVIPersonSID


SELECT * FROM #Visits 
UNION ALL
SELECT DISTINCT cm.MVIPersonSID
	,vi.EpisodeBeginDateTime
	,vi.EpisodeEndDateTime
	,vi.Active
    ,OutpatDateTime=NULL
    ,PrimaryStopCodeName = NULL
	,SecondaryStopCodeName = NULL
    ,AppointmentStatus = NULL
	,OwnerChecklistID=p.OwnerChecklistID
	,OwnerVISN=ch.VISN
    ,Sta3n = NULL
    ,DivisionName = NULL
	,ChecklistID = NULL
	,Location = NULL
	,StaffName=NULL
    ,HRF_ApptCategory = NULL
	,Inelig_Category=NULL
	,cm.PatientName
	,cm.LastFour
	,ApptCategoryDescription=NULL
	,CPTCode_Display=NULL
	,PossMissingCernerVisits=1
FROM [OracleH_QI].[PossibleMHVisits] v WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] AS cm WITH(NOLOCK)
	ON v.MVIPersonSID=cm.MVIPersonSID
INNER JOIN PRF_HRS.PatientReport_v02 p WITH (NOLOCK)
	ON v.MVIPersonSID=p.MVIPersonSID
INNER JOIN Lookup.ChecklistID ch WITH (NOLOCK)
	ON p.OwnerChecklistID=ch.ChecklistID
LEFT JOIN #Visits vi
	ON v.MVIPersonSID = vi.MVIPersonSID
WHERE vi.MVIPersonSID IS NULL
AND v.MVIPersonSID=@MVIPersonSID
--AND v.HRF=1
;

END