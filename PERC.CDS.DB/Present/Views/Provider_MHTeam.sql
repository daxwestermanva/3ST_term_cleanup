






/*
Description: View includes most recent MH team assignment (including but not limited to BHIP teams) at PatientSID level.
Modifications:

*/


CREATE VIEW [Present].[Provider_MHTeam] AS

SELECT PatientSID
	  ,MVIPersonSID
	  ,PatientICN
	  ,TeamSID
	  ,Team 
	  ,TeamType
	  ,Sta6a
	  ,ChecklistID
	  ,RelationshipStartDateTime AS RelationshipStartDate
	  ,DivisionName
FROM [Common].[Providers] WITH (NOLOCK)
WHERE TeamType IN ('MH','BHIP')
	AND TeamRank_SID=1