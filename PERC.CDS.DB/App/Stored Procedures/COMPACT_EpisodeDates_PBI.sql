
-- =============================================
-- Author:		<Liam Mina>
-- Create date: <5/15/2024>
-- Description:	

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_EpisodeDates_PBI]

AS
BEGIN
	SET NOCOUNT ON;

SELECT a.MVIPersonSID
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
	,d.Date
	,DateType = 'Active Dates'
FROM [COMPACT].[Episodes] AS a WITH(NOLOCK)
INNER JOIN [Dim].[Date] AS d WITH (NOLOCK)
	ON d.Date BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON a.MVIPersonSID = mp.MVIPersonSID
WHERE d.Date BETWEEN '2023-01-17' AND getdate()
UNION ALL
SELECT a.MVIPersonSID
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
	,d.Date
	,DateType='Begin Date'
FROM [COMPACT].[Episodes] AS a WITH(NOLOCK)
INNER JOIN [Dim].[Date] AS d WITH (NOLOCK)
	ON d.Date BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON a.MVIPersonSID = mp.MVIPersonSID
WHERE d.Date BETWEEN '2023-01-17' AND getdate()
AND d.Date=a.EpisodeBeginDate
UNION ALL
SELECT a.MVIPersonSID
	,UniqueEpisodeID=CONCAT(a.MVIPersonSID,'-',a.EpisodeRankDesc)
	,d.Date
	,DateType='End Date'
FROM [COMPACT].[Episodes] AS a WITH(NOLOCK)
INNER JOIN [Dim].[Date] AS d WITH (NOLOCK)
	ON d.Date BETWEEN a.EpisodeBeginDate AND a.EpisodeEndDate
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON a.MVIPersonSID = mp.MVIPersonSID
WHERE d.Date BETWEEN '2023-01-17' AND getdate()
AND d.Date = a.EpisodeEndDate
UNION ALL
SELECT t.MVIPersonSID
	,UniqueEpisodeID=CONCAT(t.MVIPersonSID,'-0')
	,d.Date
	,DateType='Active Dates'
FROM [COMPACT].[Template] AS t WITH (NOLOCK)
INNER JOIN [Dim].[Date] AS d WITH (NOLOCK)
	ON d.Date = CAST(t.TemplateDateTime AS date)
INNER JOIN [Common].[MasterPatient] AS mp WITH(NOLOCK) 
	ON t.MVIPersonSID = mp.MVIPersonSID 
LEFT JOIN [COMPACT].[Episodes] AS e WITH (NOLOCK)
	ON t.MVIPersonSID=e.MVIPersonSID AND CAST(t.TemplateDateTime AS date) BETWEEN e.EpisodeBeginDate AND e.EpisodeEndDate
WHERE d.Date BETWEEN '2023-01-17' AND getdate()
AND e.MVIPersonSID IS NULL

;

END