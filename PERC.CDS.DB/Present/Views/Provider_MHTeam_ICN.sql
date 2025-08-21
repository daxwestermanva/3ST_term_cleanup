






/*
Description: View includes most recent MH team assignment (including but not limited to BHIP teams) at unique patient level.
Modifications:

*/

CREATE VIEW [Present].[Provider_MHTeam_ICN] AS

SELECT MVIPersonSID
	  ,PatientICN
	  ,TeamSID
	  ,Team 
	  ,TeamType
	  ,Sta6a
	  ,ChecklistID
	  ,PatientSID
	  ,Sta3n
FROM [Common].[Providers] WITH (NOLOCK)
WHERE TeamType IN ('MH','BHIP')
	AND TeamRank_ICN=1