





/*
Description: View includes most recent BHIP team assignment at PatientSID level.
Modifications:
	20200414 - RAS	Replaced query with simpler code using new ranking fields in Present.Providers.
	20220310 - SG   Replace Pcm_std_team_care_type_id=4 to TeamType = 'BHIP'
	20221017 - EC   Added DivisionName column
*/


CREATE VIEW [Present].[Provider_BHIP] AS

SELECT   PatientSID
	  ,MVIPersonSID
	  ,PatientICN
	  ,TeamSID
	  ,Team 
	  ,Sta6a
	  ,ChecklistID
    ,RelationshipStartDateTime AS RelationshipStartDate
	,DivisionName
FROM [Common].[Providers]  WITH (NOLOCK)
WHERE TeamType = 'BHIP'
	AND TeamRank_SID=1