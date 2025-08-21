-- =============================================
-- Author:		<Liam Mina>
-- Create date: <1/3/2024>
-- Description:	

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_Episodes_PBI]

AS
BEGIN
	SET NOCOUNT ON;

SELECT DISTINCT a.MVIPersonSID
	,CASE WHEN a.ActiveEpisode=1 THEN 'Active'
		ELSE 'Inactive' END AS ActiveEpisode
	,CASE WHEN a.ActiveEpisodeSetting = 'I' THEN 'Inpatient/Residential'
		WHEN a.ActiveEpisodeSetting = 'O' THEN 'Outpatient'
		ELSE 'Inactive'
		END AS ActiveEpisodeSetting
	,a.ChecklistID_EpisodeBegin
	,CASE WHEN a.CommunityCare=1 THEN 'Community Care'
		ELSE 'Direct VA Care' END AS VACommunityCare
	,a.EncounterCodes
	,a.EpisodeBeginDate
	,EpisodeBeginSetting=REPLACE(a.EpisodeBeginSetting,'Inpatient','Inpatient/Residential')
	,a.EpisodeEndDate
	,EpisodeExtended = CASE WHEN a.EpisodeExtended=1 THEN 'Yes' ELSE 'No' END
	,a.EpisodeRankDesc
	,EpisodeTruncated = CASE WHEN a.EpisodeTruncated=1 THEN 'Yes' ELSE 'No' END
	,a.TruncateReason
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,CASE WHEN a.TemplateStart=1 THEN 'Yes'
		ELSE 'No' END AS TemplateStart
	,CASE WHEN a.ConfirmedStart=1 THEN 'Confirmed'
		ELSE 'Unconfirmed' END AS ConfirmedStart
	,c.VISN
	,c.ADMPARENT_FCDM
	,c.Facility
	,CASE WHEN ActiveEpisode=1 AND CAST(GetDate() AS date) BETWEEN CAST(DateAdd(day,-7,a.EpisodeEndDate) AS date) AND a.EpisodeEndDate THEN '1'
		WHEN ActiveEpisode=1 AND CAST(GetDate() AS date) BETWEEN CAST(DateAdd(day,-14,a.EpisodeEndDate) AS date) AND CAST(DateAdd(day,-8,a.EpisodeEndDate) AS date) THEN '2'
		WHEN ActiveEpisode=1 AND CAST(GetDate() AS date) BETWEEN CAST(DateAdd(day,-21,a.EpisodeEndDate) AS date) AND CAST(DateAdd(day,-15,a.EpisodeEndDate) AS date) THEN '3'
		WHEN ActiveEpisode=1 AND CAST(GetDate() AS date) BETWEEN CAST(DateAdd(day,-28,a.EpisodeEndDate) AS date) AND CAST(DateAdd(day,-22,a.EpisodeEndDate) AS date) THEN '4'
		WHEN ActiveEpisode=1 THEN '5+'
		END AS WeeksToEpisodeEnd
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
	,CASE WHEN h.MVIPersonSID IS NOT NULL THEN 'Yes' ELSE 'No' END AS COMPACT_Paid
FROM [COMPACT].[Episodes] AS a WITH(NOLOCK)
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON a.MVIPersonSID = mp.MVIPersonSID
INNER JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK)
	ON a.ChecklistID_EpisodeBegin = c.ChecklistID
LEFT JOIN [COMPACT].[ContactHistory] AS h WITH (NOLOCK)
	ON a.MVIPersonSID=h.MVIPersonSID AND a.EpisodeRankDesc=h.EpisodeRankDesc AND (h.ChargeRemoveReason LIKE '%COMPACT%' OR h.ChargeRemoveReason='1720J')
UNION ALL
SELECT DISTINCT t.MVIPersonSID
	,ActiveEpisode = 'Inactive'
	,ActiveEpisodeSetting=NULL
	,ChecklistID=NULL
	,VACommunityCare = 'Direct VA Care'
	,EncounterCodes=NULL
	,TemplateDateTime=NULL
	,EpisodeBeginSetting=NULL
	,TemplateDateTime=NULL
	,EpisodeExtended = NULL
	,EpisodeRankDesc=0
	,EpisodeTruncated = NULL
	,TruncateReason=NULL
	,InpatientEpisodeEndDate=NULL
	,OutpatientEpisodeBeginDate=NULL
	,TemplateStart=NULL
	,ConfirmedStart='Unconfirmed'
	,VISN=NULL
	,VISN=NULL
	,VISN=NULL
	,WeeksToEpisodeEnd=NULL
	,UniqueEpisodeID=CONCAT(t.MVIPersonSID,'-0')
	,COMPACT_Paid='No'
FROM [COMPACT].[Template] t WITH(NOLOCK) 
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON t.MVIPersonSID = mp.MVIPersonSID
LEFT JOIN [COMPACT].[Episodes] e WITH (NOLOCK)
	ON t.MVIPersonSID = e.MVIPersonSID AND CAST(t.TemplateDateTime AS date) BETWEEN e.EpisodeBeginDate AND e.EpisodeEndDate
INNER JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK)
	ON t.ChecklistID = c.ChecklistID
WHERE e.MVIPersonSID IS NULL

END