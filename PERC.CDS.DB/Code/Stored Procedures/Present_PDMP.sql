
/********************************************************************************************************************
DESCRIPTION: Get date of most recent PDMP check
AUTHOR:		 Liam Mina
CREATED:	 2020-10-26
UPDATE:	
	2021-04-14	RAS	Changed UNION to UNION ALL between VistA and Millenium data because by nature these 2 datasets 
					will not overlap and grouping/cleaning is done in next step. Same number of records expected
					in final output.
	2021-09-13	LM	Removed deleted TIU documents
	2021-09-15	AI	Enclave Refactoring - Counts confirmed
	2022-08-15  SAA_JJR Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations];New table includes DoD location data

********************************************************************************************************************/
CREATE PROCEDURE [Code].[Present_PDMP]
AS
BEGIN

DECLARE @OneYear datetime2 = CAST(DATEADD(DAY, -366, GETDATE()) AS DATE)
PRINT @OneYear

DROP TABLE IF EXISTS #PDMP
SELECT c.MVIPersonSID
         ,a.DataType
         ,a.PerformedDateTime
		 ,Sta3n=200
		 ,e.StaPa AS ChecklistID
INTO #PDMP
FROM  [EncMill].[RecordCompliance] as a WITH (NOLOCK)
INNER JOIN [EncMill].[Encounter] b WITH (NOLOCK) ON a.[EncounterSID]=b.[EncounterSID]
INNER JOIN [Cerner].[FactPatientDemographic] c WITH (NOLOCK) ON b.PersonSID=c.PersonSID
INNER JOIN [Present].[SPatient] as d WITH (NOLOCK) ON c.MVIPersonSID = d.MVIPersonSID
INNER JOIN [Cerner].[DimLocations] as e WITH (NOLOCK) ON e.OrganizationNameSID=b.OrganizationNameSID
WHERE DataType = 'PDMP Information Reviewed'  --switch to DataTypeCodeValueSID once we're fully in production, if SID value appears to remain stable
    AND b.EncounterType NOT IN ('Lifetime Pharmacy', 'History') -- email Jodie Opioid Reporting/PDMP 5.14.20 
	AND a.PerformedDateTime > @OneYear

UNION ALL 

SELECT
	mvi.MVIPersonSID
	,b.AttributeValue AS [DataType]
	,a.ReferenceDateTime AS PerformedDateTime
	,a.Sta3n
	,d.StaPa AS ChecklistID
FROM [TIU].[TIUDocument] as a WITH (NOLOCK)
INNER JOIN [Lookup].[ListMember] b WITH (NOLOCK)
	ON a.TIUDocumentDefinitionSID = b.ItemID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
	ON a.PatientSID = mvi.PatientPersonSID
INNER JOIN [Dim].[Institution] d WITH (NOLOCK)
	ON a.InstitutionSID=d.InstitutionSID
INNER JOIN [Present].[SPatient] e WITH (NOLOCK)
	ON mvi.MVIPersonSID = e.MVIPersonSID
INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
	ON a.TIUStatusSID = ts.TIUStatusSID
WHERE List='ORM_PDMP_TIU'
	AND a.ReferenceDateTime > @OneYear
	AND a.DeletionDateTime IS NULL
	AND ts.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.

DROP TABLE IF EXISTS #MaxDate
SELECT MVIPersonSID
	,MAX(PerformedDateTime) as PerformedDateTime
INTO #MaxDate
FROM #PDMP
GROUP BY MVIPersonSID

DROP TABLE IF EXISTS #MostRecentPDMP
SELECT
	b.MVIPersonSID
	,b.DataType
	,a.PerformedDateTime
	,b.Sta3n
	,b.ChecklistID
INTO #MostRecentPDMP 
FROM #MaxDate a
INNER JOIN #PDMP b ON 
	a.MVIPersonSID = b.MVIPersonSID
	AND a.PerformedDateTime = b.PerformedDateTime

EXEC [Maintenance].[PublishTable] 'Present.PDMP', '#MostRecentPDMP'

END