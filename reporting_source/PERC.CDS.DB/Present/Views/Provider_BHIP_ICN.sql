





/*
Description: View includes most recent BHIP team assignment unique patient level.
Modifications:
	20200414 - RAS	Replaced query with simpler code using new ranking fields in Present.Providers.
	20220310 - SG   Replace Pcm_std_team_care_type_id=4 to TeamType = 'BHIP'
*/

CREATE VIEW [Present].[Provider_BHIP_ICN] AS

SELECT MVIPersonSID
	  ,PatientICN
	  ,TeamSID
	  ,Team 
	  ,Sta6a
	  ,ChecklistID
	  ,PatientSID
	  ,Sta3n
FROM [Common].[Providers]  WITH (NOLOCK)
WHERE TeamType = 'BHIP'
	AND TeamRank_ICN=1