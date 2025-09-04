

/*=============================================
-- Author:		Liam Mina
-- Create date: 2024-08-09
-- Description:	Pull lists and counts of local patient record flags, for the purpose of surfacing to facilities so they can be inactivated (these flags are being phased out)
-- Updates:
--	2024-12-17	LM	Add an N/A row for facilities with no active Cat II flags

=========================================================================================================================================*/
CREATE PROCEDURE [Code].[PRF_ActiveCatII]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.PRF_ActiveCatII', @Description = 'Execution of Code.PRF_ActiveCatII SP'


--All active Cat II PRFs
DROP TABLE IF EXISTS #LocalFlags
SELECT a.Sta3n
	,a.LocalPatientRecordFlagSID
	,b.PatientRecordFlagType
	,a.LocalPatientRecordFlag
	,a.ActiveFlag
	,a.TIUDocumentDefinitionSID
	,c.TIUDocumentDefinition,
	a.LocalPatientRecordFlagDescription
INTO #LocalFlags
FROM [Dim].[LocalPatientRecordFlag] a WITH (NOLOCK)
INNER JOIN [Dim].[PatientRecordFlagType] b WITH (NOLOCK)
  ON a.Sta3n = b.Sta3n
  AND a.PatientRecordFlagTypeSID = b.PatientRecordFlagTypeSID
LEFT JOIN [Dim].[TIUDocumentDefinition] c WITH (NOLOCK)
  ON a.Sta3n = c.Sta3n
  AND a.TIUDocumentDefinitionSID = c.TIUDocumentDefinitionSID
WHERE a.ActiveFlag = 'Y'
ORDER BY a.Sta3n, b.PatientRecordFlagType, a.LocalPatientRecordFlag


DROP TABLE IF EXISTS #Counts_Patients
SELECT DISTINCT a.LocalPatientRecordFlag
	,a.LocalPatientRecordFlagDescription
	,a.LocalPatientRecordFlagSID
	,a.TIUDocumentDefinition
	,a.Sta3n
	,ISNULL(ch.ChecklistID,a.Sta3n) AS OwnerChecklistID
	,COUNT(DISTINCT fa.PatientSID) count
INTO #Counts_Patients
FROM #LocalFlags a
INNER JOIN [Lookup].[ChecklistID] v WITH (NOLOCK)
	ON a.Sta3n = v.Sta3n
LEFT JOIN [SPatient].[PatientRecordFlagAssignment] fa WITH (NOLOCK)
	ON a.LocalPatientRecordFlagSID = fa.LocalPatientRecordFlagSID
	AND fa.ActiveFlag = 'Y'
LEFT JOIN [Dim].[Institution] i WITH (NOLOCK)
	ON fa.OwnerInstitutionSID = i.InstitutionSID
LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON i.StaPa = ch.StaPa
GROUP BY a.LocalPatientRecordFlag,a.LocalPatientRecordFlagSID,a.LocalPatientRecordFlagDescription,a.TIUDocumentDefinition,a.Sta3n,ch.ChecklistID

DROP TABLE IF EXISTS #Counts
SELECT *
INTO #Counts
FROM #Counts_Patients
UNION ALL
SELECT LocalPatientRecordFlag='N/A'
	,LocalPatientRecordFlagDescription=NULL
	,LocalPatientRecordFlagSID=NULL
	,TIUDocumentDefinition=NULL
	,c.Sta3n
	,c.ChecklistID OwnerChecklistID
	,Count=0
FROM Lookup.ChecklistID c WITH (NOLOCK)
LEFT JOIN #LocalFlags f 
	ON c.Sta3n=f.Sta3n
WHERE f.Sta3n IS NULL AND c.Sta3n > 300

EXEC [Maintenance].[PublishTable] 'PRF.ActiveCatII_Counts','#Counts'

--Get data at the patient level
DROP TABLE IF EXISTS #ActiveFlags_Patient
SELECT a.LocalPatientRecordFlag
	,b.ActiveFlag
	,c.MVIPersonSID
	,ch.ChecklistID AS OwnerChecklistID
	,b.PatientRecordFlagAssignmentSID
	,a.LocalPatientRecordFlagSID
	,b.PatientSID
INTO #ActiveFlags_Patient
FROM #LocalFlags a
INNER JOIN [SPatient].[PatientRecordFlagAssignment] b WITH (NOLOCK)
	ON a.LocalPatientRecordFlagSID = b.LocalPatientRecordFlagSID
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] c WITH (NOLOCK)
	ON b.PatientSID = c.PatientPersonSID
INNER JOIN [Dim].[Institution] i WITH (NOLOCK)
	ON b.OwnerInstitutionSID = i.InstitutionSID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON i.StaPa = ch.StaPa
WHERE b.ActiveFlag='Y'

--Add last action date and type
DROP TABLE IF EXISTS #MostRecentDetails
SELECT TOP 1 WITH TIES a.MVIPersonSID
	,a.PatientSID
	,a.LocalPatientRecordFlag
	,a.LocalPatientRecordFlagSID
	,a.PatientRecordFlagAssignmentSID
	,b.ActionDateTime
	,b.PatientRecordFlagHistoryAction
INTO #MostRecentDetails
FROM #ActiveFlags_Patient a
INNER JOIN [SPatient].[PatientRecordFlagHistory] b WITH (NOLOCK)
	ON a.PatientRecordFlagAssignmentSID = b.PatientRecordFlagAssignmentSID
ORDER BY ROW_NUMBER() OVER (PARTITION BY a.PatientSID, a.LocalPatientRecordFlag ORDER BY b.ActionDateTime DESC)

DROP TABLE IF EXISTS #AddDetails
SELECT a.MVIPersonSID
	,a.PatientSID
	,a.LocalPatientRecordFlag
	,a.LocalPatientRecordFlagSID
	,a.OwnerChecklistID
	,b.ActionDateTime AS LastActionDateTime
	,CASE WHEN b.PatientRecordFlagHistoryAction=1 THEN 'New'
		WHEN b.PatientRecordFlagHistoryAction=2 THEN 'Continue'
		WHEN b.PatientRecordFlagHistoryAction=3 THEN 'Inactivate'
		WHEN b.PatientRecordFlagHistoryAction=4 THEN 'Reactivate'
		WHEN b.PatientRecordFlagHistoryAction=5 THEN 'Entered in Error'
		ELSE b.PatientRecordFlagHistoryAction
		END AS LastAction
INTO #AddDetails
FROM #ActiveFlags_Patient a
INNER JOIN #MostRecentDetails b
	ON a.PatientRecordFlagAssignmentSID=b.PatientRecordFlagAssignmentSID
	
EXEC [Maintenance].[PublishTable] 'PRF.ActiveCatII_Patients','#AddDetails'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END