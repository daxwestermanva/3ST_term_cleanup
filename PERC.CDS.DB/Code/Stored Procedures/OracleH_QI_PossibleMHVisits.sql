
/* =============================================
-- Author:		Liam Mina
-- Create date: 2023-12-14
-- Description: Identifies encounters from the OracleHealth/Cerner EHR that may be miscoded resulting in them not populating as mental health visits in dashboards/metrics.
		Pulling past 90 days of data.  Purpose is to display on some reports with the intention of surfacing to providers so they can review and correct any errors if/as necessary.
		Not all visits on this list are necessarily miscoded.
		Visits included on the list are those that do not have a VA MH Activity Type, but do have a derived stop code in the 500-series.
-- Modifications:
	2024-08-28	LM	Added encounters that exist in UtilizationOutpatient but have no charges so are missing from UtilizationStopCode
	2024-12-17	LM	Removed time restriction from join to determine if another charge in the same encounter/day counts as a MH visit

*/

CREATE PROCEDURE [Code].[OracleH_QI_PossibleMHVisits] 
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Present_Cerner_PossibleMHVisits','Execution of Code.Present_Cerner_PossibleMHVisits SP'

--Lookback past 90 days
DECLARE @Begindate date = DateAdd(day,-90,getdate())
DECLARE @EndDate date = getdate()

--Cohort of interest for displaying these visits.  We can expand to others as necessary.
DROP TABLE IF EXISTS #Cohort
SELECT a.MVIPersonSID 
	,HRF = CASE WHEN h.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
	,PDE = CASE WHEN p.MVIPersonSID IS NOT NULL THEN 1 ELSE 0 END
INTO #Cohort
FROM [Present].[ActivePatient] a WITH (NOLOCK)
LEFT JOIN [PRF_HRS].[PatientReport_v02] h WITH (NOLOCK)
	ON a.MVIPersonSID = h.MVIPersonSID
LEFT JOIN [PDE_Daily].[PDE_PatientLevel] p WITH (NOLOCK)
	ON a.MVIPersonSID = p.MVIPersonSID

--Approved VA MH Activity Types
DROP TABLE IF EXISTS #ActivityTypes
SELECT l.ItemID, l.List
INTO #ActivityTypes
FROM [Lookup].[ListMember] l WITH (NOLOCK)
WHERE Domain='ActivityType' AND List IN ('MHOC_MH','MHOC_Homeless')

--All visits with a derived stop code in the 500 series
DROP TABLE IF EXISTS #CernerPossibleMHVisits
SELECT DISTINCT a.MVIPersonSID
	,a.EncounterSID
	,a.ActivityType
	,a.GenLedgerCompanyUnitAliasNumber AS StopCode
	,a.TZServiceDateTime
	,a.SourceIdentifier
	,a.ChargeDescription
	,a.StaPa
	,EncounterType = ISNULL(o.EncounterType,a.EncounterType)
	,a.MedService
	,a.PatientLocation
	,d.CodeValueSID
	,s.NameFullFormatted AS StaffName
	,s.PersonStaffSID
INTO #CernerPossibleMHVisits
FROM [Cerner].[FactUtilizationStopCode] a WITH (NOLOCK)
INNER JOIN [Cerner].[DimActivityType] d WITH (NOLOCK)
	ON a.ActivityType = d.Display
INNER JOIN #Cohort b 
	ON a.MVIPersonSID = b.MVIPersonSID
LEFT JOIN [Cerner].[FactStaffDemographic] s
	ON a.DerivedPersonStaffSID = s.PersonStaffSID
LEFT JOIN [Cerner].[FactUtilizationOutpatient] o WITH (NOLOCK)
	ON a.EncounterSID = o.EncounterSID
WHERE (a.GenLedgerCompanyUnitAliasNumber like '5%' OR (a.MedService='Behavioral Health' and a.GenLedgerCompanyUnitAliasNumber IS NULL AND a.SourceIdentifier IS NOT NULL))
AND a.TZServiceDateTime BETWEEN @Begindate AND @EndDate

DROP TABLE IF EXISTS #NoCharges
SELECT DISTINCT a.MVIPersonSID
	,a.EncounterSID
	,a.ActivityType
	,StopCode=NULL
	,a.TZDerivedVisitDateTime
	,SourceIdentifier=NULL
	,ChargeDescription=NULL
	,a.StaPa
	,a.EncounterType
	,a.MedicalService
	,a.LocationNurseUnit
	,d.CodeValueSID
	,s.NameFullFormatted AS StaffName
	,s.PersonStaffSID
INTO #NoCharges
FROM [Cerner].[FactUtilizationOutpatient] a WITH (NOLOCK)
INNER JOIN [Cerner].[DimActivityType] d WITH (NOLOCK)
	ON a.ActivityType = d.Display
INNER JOIN #Cohort b 
	ON a.MVIPersonSID = b.MVIPersonSID
LEFT JOIN [Cerner].[FactStaffDemographic] s
	ON a.DerivedPersonStaffSID = s.PersonStaffSID
LEFT JOIN #CernerPossibleMHVisits c 
	ON a.EncounterSID = c.EncounterSID
WHERE a.MedicalService='Behavioral Health'
AND a.TZServiceDateTime BETWEEN @Begindate AND @EndDate
AND c.MVIPersonSID IS NULL

INSERT INTO #CernerPossibleMHVisits
SELECT * FROM #NoCharges

DELETE FROM #CernerPossibleMHVisits
WHERE ChargeDescription='0 Patient Side Encounter' --patient side encounter for TH visits has no workload; provider side should count

--Only visits with a VA MH activity type
DROP TABLE IF EXISTS #ConfirmedMHVisits
SELECT DISTINCT EncounterSID
	,TZServiceDateTime
	,CodeValueSID
INTO #ConfirmedMHVisits
FROM [Cerner].[FactUtilizationOutpatient] a WITH (NOLOCK)
INNER JOIN [Cerner].[DimActivityType] d 
	ON a.ActivityType = d.Display
INNER JOIN #ActivityTypes b 
	ON d.CodeValueSID = b.ItemID
WHERE a.TZServiceDateTime BETWEEN @Begindate AND @EndDate
UNION ALL
SELECT DISTINCT EncounterSID
	,TZServiceDateTime
	,CodeValueSID
FROM [Cerner].[FactUtilizationInpatientVisit] a WITH (NOLOCK)
INNER JOIN [Cerner].[DimActivityType] d WITH (NOLOCK)
	ON a.ActivityType = d.Display
INNER JOIN #ActivityTypes b 
	ON d.CodeValueSID = b.ItemID
WHERE a.TZServiceDateTime BETWEEN @Begindate AND @EndDate

--Remove the confirmed MH visits from the list of possible visits
DROP TABLE IF EXISTS #RemoveConfirmedVisits
SELECT a.MVIPersonSID
	,a.EncounterSID
	,a.ActivityType
	,a.StopCode
	,a.TZServiceDateTime
	,a.SourceIdentifier
	,a.ChargeDescription
	,a.StaPa
	,a.EncounterType
	,a.MedService
	,a.PatientLocation
	,a.CodeValueSID
	,a.StaffName
	,a.PersonStaffSID
INTO #RemoveConfirmedVisits
FROM #CernerPossibleMHVisits a
LEFT JOIN #ConfirmedMHVisits b
	ON a.EncounterSID = b.EncounterSID
	AND CAST(a.TZServiceDateTime AS date)= CAST(b.TZServiceDateTime AS date)
WHERE b.TZServiceDateTime IS NULL

DROP TABLE IF EXISTS #PossibleMissingVisits_Stage
SELECT DISTINCT a.MVIPersonSID
	,Inpatient = CASE WHEN b.EncounterType='Inpatient' THEN 1 ELSE 0 END
	,b.EncounterSID
	,b.STAPA
	,b.TZServiceDateTime
	,b.CodeValueSID
	,b.ActivityType
	,b.StopCode
	,b.EncounterType
	,b.MedService
	,b.PatientLocation
	,b.PersonStaffSID
	,b.StaffName
	,b.SourceIdentifier
	,b.ChargeDescription
	,a.HRF
	,CASE WHEN a.PDE=1 AND b.EncounterType <> 'Inpatient' THEN 1 ELSE 0 END AS PDE
INTO #PossibleMissingVisits_Stage
FROM #Cohort a
INNER JOIN #RemoveConfirmedVisits b
	ON a.MVIPersonSID = b.MVIPersonSID

--Add indicators of why the visit may not be counting as a VA MH visit
DROP TABLE IF EXISTS #AddPossibleIssues
SELECT a.MVIPersonSID
	,a.StaPa
	,a.Inpatient
	,a.EncounterSID
	,a.TZServiceDateTime
	,a.ActivityType
	,a.StopCode
	,a.EncounterType
	,a.MedService
	,a.PersonStaffSID
	,a.PatientLocation
	,a.StaffName
	,a.SourceIdentifier AS CPTCode
	,a.ChargeDescription
	,a.HRF
	,CASE WHEN a.PDE=1 AND a.EncounterType <> 'Inpatient' THEN 1 ELSE 0 END AS PDE
	,CASE WHEN b.ItemID IS NULL THEN 1 ELSE 0 END AS NonMHActivityType
	,CASE WHEN a.EncounterType LIKE 'Pre%' THEN 1 ELSE 0 END AS IncompleteEncounter
	,CASE WHEN SourceIdentifier IS NULL THEN 1 ELSE 0 END AS NoCharge
INTO #AddPossibleIssues
FROM #PossibleMissingVisits_Stage a
LEFT JOIN #ActivityTypes b 
	ON a.CodeValueSID = b.ItemID
	   	  

EXEC [Maintenance].[PublishTable] 'OracleH_QI.PossibleMHVisits','#AddPossibleIssues';

EXEC [Log].[ExecutionEnd]

END