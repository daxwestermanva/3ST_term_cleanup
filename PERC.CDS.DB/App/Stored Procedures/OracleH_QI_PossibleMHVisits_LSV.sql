




-- =============================================
-- Author:		Liam Mina
-- Create date: 2023-12-14
-- Description:	

-- EXEC [App].[OracleH_QI_PossibleMHVisits_LSV] @User = 'vha21\vhapalminal'		, @Patient = '1046399445'
-- =============================================
CREATE PROCEDURE [App].[OracleH_QI_PossibleMHVisits_LSV]
(
	@User VARCHAR(MAX),
	@Person VARCHAR(MAX),
	@Report VARCHAR(10),
	@PersonType VARCHAR(20)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(100), @Report varchar(10); SET @User = 'VHA20\VHAWCODanieC'	; SET @Patient = 15698556; SET @Report='HRF'
	--DECLARE @User varchar(max), @Person varchar(100), @Report varchar(10), @PersonType varchar(20); SET @User = 'vha21\vhapalminal'; SET @Person = 1845535246; SET @Report='HRF'; SET @PersonType='Provider'

--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Permission
	SELECT Sta3n INTO #Permission 
	FROM [App].[Access] (@User)
	
	IF @PersonType='Patient'
	BEGIN

	DECLARE @PersonList TABLE (MVIPersonSID varchar(max))
	INSERT @PersonList  SELECT value FROM string_split(@Person, ',')
	
	SELECT DISTINCT a.PatientName AS ReferenceName
		,a.MVIPersonSID AS ReferenceSID
		,CONCAT('(',a.LastFour,')') AS ReferenceLastFour
		,a.PatientName
		,a.LastFour
		,a.DateOfBirth
		,a.PatientICN
		,b.MVIPersonSID
		,b.StaPa
		,b.TZServiceDateTime
		,b.ActivityType
		,b.StopCode
		,b.EncounterType
		,b.MedService
		,b.PatientLocation
		,b.PersonStaffSID
		,b.StaffName
		,b.CPTCode
		,b.ChargeDescription
		,b.NonMHActivityType
		,b.IncompleteEncounter
		,b.NoCharge
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	INNER JOIN [OracleH_QI].[PossibleMHVisits] b WITH (NOLOCK)
		ON a.MVIPersonSID = b.MVIPersonSID
	INNER JOIN @PersonList p ON a.MVIPersonSID = p.MVIPersonSID
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON mvi.MVIPersonSID = p.MVIPersonSID
	INNER JOIN #Permission pm ON pm.Sta3n = mvi.Sta3n
		WHERE ((@Report='HRF') OR (@Report='PDE' AND PDE=1) OR @Report='')
		--display all visits in past 90 days for HRF report
		--display all possible PDE visits for PDE report
	ORDER BY TZServiceDateTime DESC

	END 

	ELSE 

	--By provider
	IF @PersonType='Provider'
	BEGIN

	DECLARE @ProviderList TABLE (ProviderSID varchar(max))
	INSERT @ProviderList  SELECT value FROM string_split(@Person, ',')
	
	SELECT DISTINCT b.StaffName AS ReferenceName
		,b.PersonStaffSID AS ReferenceSID
		,ReferenceLastFour=NULL
		,a.PatientName
		,a.LastFour
		,a.DateOfBirth
		,a.PatientICN
		,b.MVIPersonSID
		,b.StaPa
		,b.TZServiceDateTime
		,b.ActivityType
		,b.StopCode
		,b.EncounterType
		,b.MedService
		,b.PatientLocation
		,b.PersonStaffSID
		,b.StaffName
		,b.CPTCode
		,b.ChargeDescription
		,b.NonMHActivityType
		,b.IncompleteEncounter
		,b.NoCharge
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	INNER JOIN [OracleH_QI].[PossibleMHVisits] b WITH (NOLOCK)
		ON a.MVIPersonSID = b.MVIPersonSID
	INNER JOIN Lookup.ChecklistID ch WITH (NOLOCK)
		ON b.StaPa = ch.StaPa
	INNER JOIN @ProviderList p ON b.PersonStaffSID = p.ProviderSID
	INNER JOIN #Permission pm ON pm.Sta3n = ch.STA3N
	ORDER BY TZServiceDateTime DESC

	END
	;

END