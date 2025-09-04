

-- =============================================
-- Author:		<Liam Mina>
-- Create date: <11/08/2019>
-- Description:	Get inpatient and recent discharge information
-- Modifications:
	-- 2020-09-21	RAS	Switched initial #patient join to use Common.MasterPatient instead of Present.StationAssignments

-- EXEC [App].[MBC_Inpatient_LSV] @User = 'VHAMASTER\VHAISBBACANJ'	, @Patient = '1001052545'
-- EXEC [App].[MBC_Inpatient_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1009833981'
---- =============================================
CREATE PROCEDURE [App].[MBC_Inpatient_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1001052545'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @Patient = '1009664995'

	
--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	SELECT DISTINCT a.MVIPersonSID
      ,a.AMA AS AMADischarge
      ,cast(a.Census as int) as Census
      ,CONVERT(VARCHAR(10), a.DischargeDateTime, 101) as DischargeDate
      ,CONVERT(VARCHAR(10), a.AdmitDateTime, 101) as AdmitDate
	  ,CASE WHEN a.MentalHealth_TreatingSpecialty = 1 THEN 'Acute MH Inpatient'
		WHEN a.RRTP_TreatingSpecialty=1 THEN 'MH Residential'
		WHEN a.MedSurgInpatient_TreatingSpecialty = 1 THEN 'Inpatient Medical/Surgical'
		WHEN a.NursingHome_TreatingSpecialty=1 THEN 'Nursing Home'
		END AS InpatientType
      ,a.BedSectionName
      ,a.ChecklistID AS ChecklistID_Discharge
      ,l.Facility AS Facility_Discharge
	  ,ROW_NUMBER() OVER (PARTITION BY a.ChecklistID ORDER BY a.Census DESC, a.DischargeDateTime DESC) AS RowNum
	FROM [Inpatient].[Bedsection] a WITH (NOLOCK)
	INNER JOIN #Patient p 
		ON p.MVIPersonSID=a.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] as l WITH (NOLOCK) 
		ON a.ChecklistID = l.ChecklistID
	WHERE a.Census=1 OR a.DischargeDateTime > DateAdd(day,-366,getdate())


END