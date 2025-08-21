

/*  =============================================
--  Author: Rebecca Stephens (RAS)		 
--  Create date: 2017-09-20
--  Description:	Main dataset for post discharge engagement dashboard
--  Modifications:
    2018-05-31 RAS: Added case statements to change census parameter to include past 90, 60, 30 days
	20190419   RAS: Addded join with StationAssignments to get PatientName and LastFour.  
					Added join with Reach PatientReport to get ReachStatus.
	2022-11-01 EC:  Added @Provider parameter for filtering by MHTC or BHIP Team
	2024-03-28 EC:  Added DateOfBirth to make it easier to look up Cerner patients
	2025-03-17 EC:  Added COMPACT Act Active Episode indicator, Overdose_Dx indicator, SPC
    =============================================
	EXEC [App].[PDE_PatientTracking] @User = 'VHA21\vhapalstephr6'--'VHA21\vhapaladamss' --this person has only 640 acess
	    ,@Facility='640'
	    ,@FacilityType='1,2,3',@Census='0,1',@ProviderType='2' ,@Provider='-1'
    ============================================= */
CREATE PROCEDURE [App].[PDE_PatientTracking]

	 @User varchar(50)
	,@Facility varchar(12)
	,@FacilityType varchar(50)
	,@census varchar(12)
	,@Provider varchar(max)
	,@ProviderType varchar(max)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	
DECLARE @Staff TABLE (ProviderSID_MHTC VARCHAR(250));

INSERT @Staff SELECT value FROM string_split(@Provider, ',');

	
SELECT a.*
FROM (
	SELECT DISTINCT 
		--Patient Info
		 pde.MVIPersonSID
		,mp.PatientName
		,mp.LastFour
		,mp.PatientICN
		,mp.EDIPI
		,CAST(mp.DateOfBirth AS DATE) as DateOfBirth
		,mp.PhoneNumber as PhoneResidence
		,mp.CellPhoneNumber as PhoneCellular

		--Inpatient Admission Dates
		,Census=CASE WHEN pde.DischargeDateTime IS NULL OR pde.DischargeDateTime>GETDATE() THEN 0
			WHEN DATEDIFF(DAY,pde.DischargeDateTime,GETDATE()) > 60 THEN 3
			WHEN DATEDIFF(DAY,pde.DischargeDateTime,GETDATE()) > 30 THEN 2
			WHEN pde.DischargeDateTime<= GETDATE() THEN 1
			END
		,pde.AdmitDateTime
		,DischargeDateTime=CASE WHEN pde.Census=1 THEN NULL ELSE pde.DischargeDateTime END
		,pde.DisDay

		--Inpatient Admission Location
		,pde.Discharge_Sta6a
		,pde.ChecklistID_Discharge
		,pde.Facility_Discharge
		,pde.Disch_BedSecn
		,pde.Disch_BedSecName
		,pde.MedicalService
		,pde.Accommodation

		--Inpatient Admission Type
		,pde.AMADischarge
		,DischBedGroup=CASE WHEN pde.DischBed_MH_Acute=1 THEN 'MH Acute'
			WHEN pde.DischBed_MH_res=1 THEN 'MH Residential'
			WHEN pde.DischBed_NMH=1 THEN 'Non Mental Health'
			END
		,PDE_Grp=CASE WHEN pde.PDE_GRP=1 AND pde.G1_MH_Final=1 THEN 0
			WHEN pde.PDE_GRP=1 AND pde.G1_MH_Final=0 THEN 1
			WHEN pde.PDE_GRP=2 THEN 2
			WHEN pde.PDE_GRP=3 THEN 3
			END 
		,GroupName=CASE WHEN pde.PDE_GRP=1 AND pde.G1_MH_Final=1 THEN 'MH Residential Program'
			WHEN pde.PDE_GRP=1 AND pde.G1_MH_Final=0 THEN 'Non-MH Treating Specialty with MH Diagnosis'
			WHEN pde.PDE_GRP=2 THEN 'MH Inpatient'
			WHEN pde.PDE_GRP=3 THEN 'High Risk for Suicide' 
			END 
		,pde.G1_MH_Final

		--Inpatient Admission Diagnosese
		,pde.AdmitDiagnosis
		,pde.PrincipalDiagnosisICD10Code
		,pde.PrincipalDiagnosisICD10DESC
		,pde.SUD_Dx
		,pde.SUD_Dx_Label
		,pde.Overdose_Dx
		,pde.SI_Dx
		,pde.SuicideRelated_Dx_Label

		--Visits required and needed to meet measure
		,pde.PostDisch_30days
		,pde.RNTMM
		,VNTMM=ISNULL(pde.VNTMM,(pde.RNTMM - pde.NumberofMentalHealthVisits))
		,MetNotMet=CAST(pde.PDE1 AS CHAR(1)) 
	
		--MH Visit Info
		,'AnyVisits' = CASE WHEN v.MVIPersonSID IS NOT NULL THEN 1 ELSE NULL END
		,pde.NumberOfMentalHealthVisits
  		,pde.FirstVisitDateTime
		,pde.FirstClName
		,pde.FirstProviderName
		,pde.LastVisitDateTime
		,pde.LastClName
		,pde.LastProviderName
		,pde.FutureApptDate
		,pde.ApptDays
		,CASE WHEN mh.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END AS PossMHVisit_OracleH

		--Provider Info
		,pde.Facility_Home
		,pde.StaffName_PCP
		,pde.DivisionName_PCP
		,pde.StaffName_MHTC
		,pde.DivisionName_MHTC
		,pde.TeamName_BHIP
		,pde.DivisionName_BHIP
		,spc.AssignedSPC

		--Homestation and EHR
		,pde.ChecklistID_Metric
		,pde.Facility_Metric
		,pde.ChecklistID_Home
		,mp.SourceEHR

		--High Risk Flag for Suicide
		,pde.HRF
		,HRF_Current=CASE WHEN h.PatientICN IS NOT NULL THEN 1 ELSE 0 END
		,HRF_Action=CASE WHEN h.ActionType IS NULL THEN pde.PatientRecordFlagHistoryAction ELSE h.ActionType END
		,HRF_ActionDate=CASE WHEN h.ActionDateTime IS NULL THEN pde.HRF_ActionDate ELSE h.ActionDateTime END
		,spc.OwnerChecklistID

		-- REACH VET 
		,ReachStatus=CASE WHEN r.Top01Percent=1 THEN 1
			WHEN r.Top01Percent=0 THEN 2
			ELSE 0 END 

		--COMPACT Active Episode
		,'COMPACT' = CASE WHEN cmp.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
		,cmp.EpisodeBeginDate
		,cmp.EpisodeEndDate
		,cmp.ConfirmedStart
		
		--Date of last update
		,pde.UpdateDate

		FROM [PDE_Daily].[PDE_PatientLevel] as pde WITH (NOLOCK)
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
		ON mp.MVIPersonSID=pde.MVIPersonSID
	LEFT JOIN [PRF_HRS].[ActivePRF] as h WITH (NOLOCK)
		on h.MVIPersonSID=pde.MVIPersonSID
	LEFT JOIN [REACH].[History] as r WITH (NOLOCK)
		on r.MVIPersonSID=mp.MVIPersonSID
	LEFT JOIN [COMPACT].[Episodes] as cmp
		on pde.MVIPersonSID = cmp.MVIPersonSID and cmp.ActiveEpisode=1
	LEFT JOIN [PDE_Daily].[PDE_FollowUpMHVisits] as v WITH (NOLOCK)
		on pde.MVIPersonSID = v.MVIPersonSID and pde.DisDay = v.DisDay
	LEFT JOIN [PRF_HRS].[PatientReport_v02] as spc WITH (NOLOCK)
		on pde.MVIPersonSID = spc.MVIPersonSID AND spc.ActiveFlag='Y'
	LEFT JOIN [OracleH_QI].PossibleMHVisits mh WITH (NOLOCK)
		ON pde.MVIPersonSID=mh.MVIPersonSID AND mh.PDE=1 
	INNER JOIN [LookUp].[ChecklistID] as c WITH (NOLOCK)
		ON c.ChecklistID=ChecklistID_Home 
		OR c.ChecklistID=ChecklistID_Metric
		OR c.ChecklistID=ChecklistID_Discharge
	INNER JOIN @Staff AS s ON s.ProviderSID_MHTC=pde.ProviderSID_MHTC or s.ProviderSID_MHTC=pde.TeamSID_BHIP
	INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as Access ON c.STA3N = Access.Sta3n
	WHERE pde.Exclusion30=0
		AND (
			   (@Facility=pde.ChecklistID_Metric	AND '1' IN (SELECT value FROM string_split(@FacilityType ,',')))
			OR (@Facility=pde.ChecklistID_Discharge AND '2' IN (SELECT value FROM string_split(@FacilityType ,',')))
			OR (@Facility=pde.ChecklistID_Home		AND '3' IN (SELECT value FROM string_split(@FacilityType ,',')))
			)
		AND (
			(@ProviderType='1' AND pde.ProviderSID_MHTC IN (SELECT value FROM string_split(@Provider ,',')))
			OR (@ProviderType='2' AND pde.TeamSID_BHIP IN (SELECT value FROM string_split(@Provider ,',')))
			)
	) a
WHERE a.Census IN (SELECT value FROM string_split(@census ,','))
ORDER BY DischargeDateTime


END