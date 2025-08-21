-- =============================================
-- Author:		<Liam Mina>
-- Create date: <1/4/2024>
-- Description:	

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_ContactHistory_PBI]

AS
BEGIN
	SET NOCOUNT ON;

SELECT DISTINCT
	ContactType=CASE WHEN a.ContactType LIKE '%Inpatient%' THEN REPLACE(a.ContactType,'Inpatient','Inpatient/Residential')
		WHEN i.MVIPersonSID IS NOT NULL AND a.ContactType='Outpatient Encounter' THEN CONCAT(a.ContactType,' (Admitted)')
		ELSE a.ContactType END
	,a.EncounterCodes
	,a.EncounterEndDate
	,a.EncounterStartDate
	,a.MVIPersonSID
	,a.Sta6a
	,CASE WHEN a.Template = 1 THEN 'Yes'
		ELSE 'No' END AS Template_Text
	,a.Detail
	,StaffName=REPLACE(a.StaffName,',',', ')
	,c.ChecklistID --ChecklistID where care happened
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
	,e.ChecklistID_EpisodeBegin --ChecklistID where episode began
	,CASE WHEN c.ChecklistID = e.ChecklistID_EpisodeBegin THEN 1 ELSE 0 END CareAtChecklistID_EpisodeBegin --did care happen at facility where episode began
	,a.CPTCodes_All
	,a.COMPACTAction
	,a.COMPACTCategory
	,a.TotalCharge
	,a.BriefDescription
	,a.ChargeRemoveReason
	,CASE WHEN  a.Sta3n_EHR=200 THEN NULL --don't have billing data for Cerner sites incorporated yet 2025-04-21
		WHEN a.TotalCharge IS NULL THEN 'N/A' -- if there is no charge on the encounter leave blank
		WHEN a.ChargeRemoveReason IS NULL AND a.ContactType NOT LIKE 'CC%' THEN 'No' 
		ELSE 'Yes' END AS ChargeRemoved
FROM [COMPACT].[ContactHistory] AS a WITH(NOLOCK)
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON a.MVIPersonSID = mp.MVIPersonSID
INNER JOIN [Lookup].[Sta6a] AS c WITH (NOLOCK)
	ON a.Sta6a = c.Sta6a
LEFT JOIN [COMPACT].[Episodes] AS e WITH (NOLOCK)
	ON a.MVIPersonSID = e.MVIPersonSID AND a.EpisodeRankDesc = e.EpisodeRankDesc
LEFT JOIN [Common].[InpatientRecords_002] i WITH (NOLOCK)
	ON a.MVIPersonSID=i.MVIPersonSID AND a.EncounterStartDate BETWEEN i.AdmitDateTime AND ISNULL(i.DischargeDateTime,getdate())
WHERE( a.EncounterEndDate > DateAdd(day,-366,getdate()) OR a.EncounterEndDate IS NULL OR e.ActiveEpisode=1)

END