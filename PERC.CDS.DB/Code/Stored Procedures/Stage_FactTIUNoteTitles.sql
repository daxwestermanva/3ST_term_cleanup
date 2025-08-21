

/*=============================================
-- Author:		Liam Mina
-- Create date: 2024-04-19
-- Description:	Get TIU fact data for select note titles in lookup for use in downstream procedures 
-- Modifications:

  =============================================*/

CREATE PROCEDURE [Code].[Stage_FactTIUNoteTitles]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.Stage_FactTIUNoteTitles','Execution of Code.Stage_FactTIUNoteTitles SP'

DECLARE @PastYear date = CAST(DateAdd(day,-366,getdate()) AS date)
DECLARE @SPNotes date = '2018-01-01'
DECLARE @ORMNotes date = '2014-05-06'


DROP TABLE IF EXISTS #VistA_TIU
SELECT m.MVIPersonSID	
	,t.TIUDocumentSID
	,t.TIUDocumentDefinitionSID
	,DocFormActivitySID = NULL
	,t.EntryDateTime
	,t.ReferenceDateTime
	,t.VisitSID
	,t.SecondaryVisitSID
	,t.Sta3n
	,ISNULL(d.Sta6a,t.Sta3n) AS Sta6a
	,ISNULL(s.StaPa,t.Sta3n) AS StaPa
	,l.AttributeValue AS TIUDocumentDefinition
	,l.List
INTO #VistA_TIU
FROM [TIU].[TIUDocument] t WITH (NOLOCK)
INNER JOIN [Lookup].[ListMember] l WITH (NOLOCK) 
	ON t.TIUDocumentDefinitionSID = l.ItemID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] m WITH (NOLOCK) 
	ON t.PatientSID = m.PatientPersonSID
INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
	ON t.TIUStatusSID = ts.TIUStatusSID
LEFT JOIN [Dim].[Division] d WITH (NOLOCK)
	ON t.InstitutionSID = d.InstitutionSID
LEFT JOIN [Lookup].[Sta6a] s WITH (NOLOCK)
	ON d.Sta6a = s.Sta6a
WHERE (
	--(List IN ('ORM_PDMP_TIU','ORM_CIH_TIU','BloodPressure_TIU') AND t.EntryDateTime >=@PastYear)
	--OR 
	(List IN ('HRF_FlagReview_TIU','SuicidePrevention_SP_ReviewDecline_TIU','SuicidePrevention_CSRE_TIU','SuicidePrevention_SBOR_TIU','SuicideRiskManagement_TIU')
		AND t.EntryDateTime >= @SPNotes)
	--OR (List IN('ORM_DatabasedReview_TIU','ORM_InformedConsent_TIU') AND t.EntryDateTime >= @ORMNotes)
	OR (List='SuicidePrevention_SafetyPlan_TIU')) -- all time
AND t.DeletionDateTime IS NULL
AND ts.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.


DROP TABLE IF EXISTS #CernerNote
SELECT t.MVIPersonSID	
	,t.EventSID
	,t.EventCodeSID
	,DocFormActivitySID = NULL
	,t.TZPerformedUTCDateTime
	,t.TZEventEndUTCDateTime
	,t.EncounterSID
	,SecondaryVisitSID=NULL
	,Sta3n=200
	,t.Sta6a
	,t.StaPa
	,l.AttributeValue AS TIUDocumentDefinition
	,l.List
INTO #CernerNote
FROM [Cerner].[FactNoteTitle] t WITH (NOLOCK)
INNER JOIN [Lookup].[ListMember] l WITH (NOLOCK)
	ON t.EventCodeSID = l.ItemID
WHERE (
	--(List IN ('ORM_PDMP_TIU','ORM_CIH_TIU','BloodPressure_TIU') AND t.TZPerformedUTCDateTime >=@PastYear)
	--OR 
	(List IN ('HRF_FlagReview_TIU','SuicidePrevention_SP_ReviewDecline_TIU','SuicidePrevention_CSRE_TIU','SuicidePrevention_SBOR_TIU','SuicideRiskManagement_TIU')
	AND t.TZPerformedUTCDateTime >= @SPNotes)
--OR (List IN('ORM_DatabasedReview_TIU','ORM_InformedConsent_TIU') AND t.TZPerformedUTCDateTime >= @ORMNotes)
OR (List='SuicidePrevention_SafetyPlan_TIU')) -- all time

DROP TABLE IF EXISTS #PowerForm
SELECT DISTINCT t.MVIPersonSID	
	,t.DocFormActivitySID AS TIUDocumentSID
	,t.DCPFormsReferenceSID
	,t.DocFormActivitySID
	,t.TZFormUTCDateTime
	,t.TZFormUTCDateTime AS ReferenceDateTime
	,t.EncounterSID
	,SecondaryVisitSID=NULL
	,Sta3n=200
	,t.Sta6a
	,t.StaPa
	,l.AttributeValue AS TIUDocumentDefinition
	,l.List
INTO #PowerForm
FROM [Cerner].[FactPowerForm] t WITH (NOLOCK)
INNER JOIN [Lookup].[ListMember] l WITH (NOLOCK)
	ON t.DCPFormsReferenceSID = l.ItemID
WHERE (
	--(List IN ('ORM_PDMP_TIU','ORM_CIH_TIU','BloodPressure_TIU') AND t.TZFormUTCDateTime >=@PastYear)
	--OR 
	(List IN ('HRF_FlagReview_TIU','SuicidePrevention_SP_ReviewDecline_TIU','SuicidePrevention_CSRE_TIU','SuicidePrevention_SBOR_TIU','SuicideRiskManagement_TIU')
	AND t.TZFormUTCDateTime >= @SPNotes)
--OR ((l.ORM_DatabasedReview_TIU=1 OR l.ORM_InformedConsent_TIU=1) AND t.TZFormUTCDateTime >= @ORMNotes)
OR (List='SuicidePrevention_SafetyPlan_TIU')) -- all time

DROP TABLE IF EXISTS #tiu_stage
SELECT DISTINCT *
INTO #tiu_stage
FROM #VistA_TIU
UNION ALL
SELECT DISTINCT * FROM #CernerNote
UNION ALL
SELECT DISTINCT * FROM #PowerForm


EXEC [Maintenance].[PublishTable] '[Stage].[FactTIUNoteTitles]','#tiu_stage'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END