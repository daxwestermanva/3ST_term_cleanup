
-- =============================================
-- Author:		<Liam Mina>
-- Create date: <1/3/2024>
-- Description:	Facilities where patient should appear on COMPACT report: 
--					1. Facility where episode begain
--					2. Facilties where patient has recieved follow up care within the episode
--					3. Facilities where COMPACT template has been documented
--					4. Facilities where patient in an active episode has an upcoming appointment
--					5. Facilities where patient has an active HRS-PRF

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_PatientFacility_PBI]

AS
BEGIN
	SET NOCOUNT ON;

--Facility where episode started
SELECT DISTINCT a.MVIPersonSID
	,ch.ADMPARENT_FCDM AS Facility
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
	,InclusionReason = 'Episode Initiated at Facility'
	,ch.ChecklistID
FROM [COMPACT].[Episodes] AS a WITH(NOLOCK)
INNER JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK)
	ON a.MVIPersonSID=mp.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON a.ChecklistID_EpisodeBegin=ch.ChecklistID
UNION
--Facility where care was recieved
SELECT DISTINCT c.MVIPersonSID
	,ch.ADMPARENT_FCDM AS Facility
	,UniqueEpisodeID=CONCAT(c.MVIPersonSID,'-',c.EpisodeRankDesc)
	,InclusionReason = 'Contact Documented at Facility'
	,ch.ChecklistID
FROM [COMPACT].[ContactHistory] AS c WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK)
	ON c.MVIPersonSID=mp.MVIPersonSID
INNER JOIN [Lookup].[Sta6a] s WITH (NOLOCK)
	ON c.Sta6a=s.Sta6a
INNER JOIN [COMPACT].[Episodes] AS e WITH (NOLOCK)
	ON c.MVIPersonSID = e.MVIPersonSID 
	AND c.EpisodeRankDesc = e.EpisodeRankDesc
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON s.ChecklistID = ch.ChecklistID
UNION
--Facility where COMPACT template was documented
SELECT DISTINCT c.MVIPersonSID
	,ch.ADMPARENT_FCDM AS Facility
	,UniqueEpisodeID=CONCAT(c.MVIPersonSID,'-',ISNULL(e.EpisodeRankDesc,'0'))
	,InclusionReason='COMPACT Template Documented at Facility'
	,ch.ChecklistID
FROM [COMPACT].[Template] AS c WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK)
	ON c.MVIPersonSID=mp.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON c.ChecklistID = ch.ChecklistID
LEFT JOIN [COMPACT].[Episodes] AS e WITH (NOLOCK)
	ON c.MVIPersonSID = e.MVIPersonSID 
	AND CAST(c.TemplateDateTime AS date) BETWEEN e.EpisodeBeginDate AND e.EpisodeEndDate
UNION 
--Facility where patient has an upcoming appointment
SELECT DISTINCT c.MVIPersonSID
	,ch.ADMPARENT_FCDM AS Facility
	,UniqueEpisodeID=CONCAT(c.MVIPersonSID,'-',e.EpisodeRankDesc)
	,InclusionReason = 'Upcoming Appointment at Facility'
	,ch.ChecklistID
FROM [Present].[AppointmentsFuture] AS c WITH (NOLOCK)
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON c.ChecklistID = ch.ChecklistID
INNER JOIN [COMPACT].[Episodes] AS e WITH (NOLOCK)
	ON c.MVIPersonSID = e.MVIPersonSID 
	AND e.ActiveEpisode = 1
UNION 
--Facility where patient has an active flag
SELECT DISTINCT c.MVIPersonSID
	,ch.ADMPARENT_FCDM AS Facility
	,UniqueEpisodeID=CONCAT(c.MVIPersonSID,'-',e.EpisodeRankDesc)
	,InclusionReason = 'Active HRS-PRF Owned by Facility'
	,ch.ChecklistID
FROM [PRF_HRS].PatientReport_v02 AS c WITH (NOLOCK)
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON c.OwnerChecklistID = ch.ChecklistID
INNER JOIN [COMPACT].[Episodes] AS e WITH (NOLOCK)
	ON c.MVIPersonSID = e.MVIPersonSID 
WHERE c.ActiveFlag='Y'
UNION 
--Allow test patients to display at all sites for demo mode
SELECT DISTINCT a.MVIPersonSID
	,ch.ADMPARENT_FCDM AS Facility
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
	,InclusionReason = 'Test Patient'
	,ch.ChecklistID
FROM [COMPACT].[Episodes] AS a WITH(NOLOCK)
INNER JOIN [Common].[MasterPatient] AS mp WITH (NOLOCK)
	ON a.MVIPersonSID=mp.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
	ON a.ChecklistID_EpisodeBegin<>ch.ChecklistID
WHERE mp.TestPatient=1
AND ch.Sta3n>300







END