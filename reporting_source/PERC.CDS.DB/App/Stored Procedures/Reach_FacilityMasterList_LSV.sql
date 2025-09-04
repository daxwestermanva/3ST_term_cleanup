-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <9/19/2016>
-- Description:	Main data date for the Persceptive Reach report

-- 2019-05-09 - LM - Added fields from REACH.History table
-- 2020-10-02 - RAS - Replaced StationAssignments with Common.MasterPatient
-- 2020-10-05 - LM - pointed to _VM tables for Cerner overlay
-- 2020-10-15 - LM - Added SourceEHR to indicate possible Cerner data
-- 2021-01-19 - LM - Added division name of other future appointment
-- 2021-04-21 - LM - Added eligibility status
-- 2021-04-23 - LM - Flagging patients who were incorrectly excluded from (and later added back to) dashboard in April 2021
-- 2021-05-11 - LM - Removing April Correction
-- 2022-05-16 - LM - Added Date of Birth for easier patient lookup in Cerner
-- 2022-11-30 - LM - Added Patient Status from health factors (outpatient, inpatient, incarcerated)
-- 2023-06-30 - JEB - Because [Reach].[RiskScore] was changed to have ImpactedByRandomization, the referenced field was also changed
-- 2025-05-06 - LM - Updated references to point to REACH 2.0 objects
/*
EXEC [App].[Reach_FacilityMasterList_LSV]
    @User= 'vha21\vhapalstephr6',
	@Station='668', --'612%',
	--@MVIPersonSID =-1,
	@QuestionNumber =0,
	@QuestionStatus =0
  */
-- =============================================
CREATE PROCEDURE [App].[Reach_FacilityMasterList_LSV]

    @User varchar(max),
	@Station varchar(max),
	--@MVIPersonSID INT,
	@QuestionNumber varchar(10),
	@QuestionStatus int
    --@PatientICN varchar(1000)	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


 --declare  @User varchar(max) set @User= 'vha21\vhapalstephr6'  declare @Station varchar(max) set 	@Station='614'	--@QuestionNumber =0,	@QuestionStatus =0
drop table if exists #Access
SELECT Sta3n 
INTO #Access
FROM [App].[Access] (@User)
WHERE Sta3n=LEFT(@Station,3)
 
 
 
SELECT  a.ChecklistID
	  ,a.MVIPersonSID
	  ,p.PatientName
	  ,p.PreferredName
	  ,p.PatientSSN
	  ,p.PatientICN
	  ,p.DateOfBirth
	  ,h.Top01Percent
	  ,p.StreetAddress1
	  ,p.StreetAddress2
	  ,p.StreetAddress3
	  ,p.City
	  ,p.State AS StateAbbrev
	  ,p.Zip
	  ,s.CareEvaluationChecklist
	  ,s.FollowUpWithTheVeteran
	  ,s.InitiationChecklist
	  ,s.ProviderAcknowledgement
	  ,CASE WHEN s.PatientStatus = 1 THEN 'Outpatient'
		WHEN s.PatientStatus = 2 THEN 'Admitted'
		WHEN s.PatientStatus = 3 THEN 'Incarcerated'
		END AS PatientStatus
	  ,s.PatientDeceased AS Deceased
	  ,s.LastCoordinatorActivity
	  ,s.LastProviderActivity
	  ,s.CoordinatorName AS Coordinator
	  ,s.ProviderName
	  ,p.PhoneNumber AS HomePhone
	  ,p.CellPhoneNumber AS CellPhone
	  ,e.Bipoli24 
	  ,a.Admitted
	  ,rv.MHVisits
	  ,CASE WHEN h.Top01Percent = 1 THEN 1
		--Because [Reach].[RiskScore] was changed to have ImpactedByRandomization, the referenced field was also changed
		WHEN rv.ImpactedByRandomization = 1 and h.Top01Percent = 0 then 5
		WHEN h.MonthsIdentified12 IS NOT NULL THEN 2
		WHEN h.MonthsIdentified24 IS NOT NULL THEN 3
		ELSE 4 END AS RVStatus
	  ,h.FirstRVDate
	  ,h.LastIdentifiedExcludingCurrentMonth
	  ,NextAppointment=
		CASE WHEN a.MHFutureAppointmentDateTime_ICN IS NOT NULL THEN a.MHFutureAppointmentDateTime_ICN
		WHEN a.PCFutureAppointmentDateTime_ICN<a.OtherFutureAppointmentDateTime_ICN THEN a.PCFutureAppointmentDateTime_ICN 
		ELSE a.OtherFutureAppointmentDateTime_ICN END
	  ,NextAppointmentLocation=
		CASE WHEN a.MHFutureAppointmentFacility_ICN IS NOT NULL THEN a.MHFutureAppointmentFacility_ICN
		WHEN a.PCFutureAppointmentDateTime_ICN<a.OtherFutureAppointmentDateTime_ICN THEN a.PCFutureAppointmentFacility_ICN 
		ELSE a.OtherFutureAppointmentFacility_ICN END
	  ,CASE WHEN p.PriorityGroup between 1 and 8 AND p.PrioritySubGroup NOT IN ('g','e') THEN 'Eligible'
		WHEN p.PriorityGroup=8 AND p.PrioritySubGroup IN ('g','e') THEN 'Ineligible (' + CONCAT(p.PriorityGroup,p.PrioritySubGroup) + ')'
		ELSE 'Ineligible' END AS Eligibility
	  ,ReleaseDate=(SELECT max(ReleaseDate) FROM [REACH].[RiskScoreHistoric])
	  ,p.SourceEHR
	  ,CONVERT(varchar, s.UpdateDate, 0) AS UpdateDate

FROM [REACH].[PatientReport] AS a WITH(NOLOCK)
INNER JOIN #Access AS acs 
	ON LEFT(a.ChecklistID,3) = acs.sta3n
LEFT JOIN [REACH].[RiskScore] AS rv WITH (NOLOCK)
	ON a.PatientSID = rv.PatientPersonSID
INNER JOIN [Common].[MasterPatient] AS p WITH(NOLOCK) 
	ON p.MVIPersonSID=a.MVIPersonSID 
LEFT JOIN [REACH].[QuestionStatus] AS s WITH(NOLOCK) 
	ON a.MVIPersonSID = s.MVIPersonSID
LEFT JOIN (
	SELECT MVIPersonSID,Bipoli24=1
	FROM [Reach].[PatientRisks] WITH(NOLOCK) 
	WHERE Risk='bipoli24'
	) AS e 
	ON a.MVIPersonSID = e.MVIPersonSID
LEFT JOIN [REACH].[History] AS h WITH(NOLOCK) 
	ON a.MVIPersonSID = h.MVIPersonSID
WHERE a.ChecklistID=@Station

 
END