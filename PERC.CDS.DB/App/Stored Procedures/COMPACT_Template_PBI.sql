
-- =============================================
-- Author:		<Liam Mina>
-- Create date: <5/14/2024>
-- Description:	

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_Template_PBI]

AS
BEGIN
	SET NOCOUNT ON;

SELECT DISTINCT a.MVIPersonSID
	,a.TemplateDateTime
	,a.TemplateSelection
	,TypeDocumented = 
		CASE WHEN a.List='COMPACT_EndEpisode' THEN 'Non-Acute: End Episode'
			WHEN a.List='COMPACT_InitialCare' THEN 'Initial Care-VA'
			WHEN a.List='COMPACT_FollowUpCare' THEN 'Follow Up Care-VA'
			WHEN a.List='COMPACT_30DayExtensionOfCare' THEN 'Episode Extension'
			WHEN a.List='COMPACT_InitialCareCommunity' THEN 'Community Care'
			END
	,CASE WHEN c.MVIPersonSID IS NOT NULL THEN 'Yes' ELSE 'No' END AS WithinEpisode
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',ISNULL(c.EpisodeRankDesc,0))
	,a.StaffName
	,ch.ChecklistID
FROM [COMPACT].[Template] AS a WITH(NOLOCK)
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON a.MVIPersonSID = mp.MVIPersonSID
LEFT JOIN [COMPACT].[Episodes] AS c WITH (NOLOCK)
	ON a.MVIPersonSID = c.MVIPersonSID AND CAST(a.TemplateDateTime AS date) BETWEEN c.EpisodeBeginDate AND c.EpisodeEndDate
LEFT JOIN [Lookup].[ChecklistID] AS ch WITH (NOLOCK)
	ON a.ChecklistID = ch.ChecklistID


END