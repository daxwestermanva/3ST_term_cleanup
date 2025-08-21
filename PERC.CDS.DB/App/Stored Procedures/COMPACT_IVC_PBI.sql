
-- =============================================
-- Author:		<Liam Mina>
-- Create date: <7/18/2024>
-- Description:	

--Updates

-- =============================================
CREATE PROCEDURE [App].[COMPACT_IVC_PBI]

AS
BEGIN
	SET NOCOUNT ON;

SELECT e.MVIPersonSID
	,UniqueEpisodeID=CONCAT(e.MVIPersonSID,'-',e.EpisodeRankDesc)
	,i.BeginDate
	,i.TxSetting
	,i.Hospital
FROM [COMPACT].[IVC] i WITH (NOLOCK)
INNER JOIN [COMPACT].[Episodes] e WITH (NOLOCK)
	ON i.MVIPersonSID = e.MVIPersonSID
	AND CAST(i.BeginDate AS date) BETWEEN e.EpisodeBeginDate AND e.EpisodeEndDate
WHERE i.Hospital IS NOT NULL

END