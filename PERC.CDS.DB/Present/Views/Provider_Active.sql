







/*
Description: View to filter Present.Providers to only active staff (primary or associate provider).
Modifications:
	20200410 - RAS	Updated view to include all current fields in Present.Providers.
					Added ActiveStaffA to WHERE statement (active primary provider OR active associate provider)
	20201202 - LM	Added EDIPI values as provider identifiers from Cerner sites
	20220310 - SG	Based on VSSC RPCMM table, Remove Column pcm_std_team_care_type_id,TeamRoleCode,AssociateProviderEDIPI
	                update RelationshipStartDateTime,RelationshipEndDateTime
					Use ActiveAny instead of (ActiveStaffA=1 or ActiveStaff=1)
					Added TeamType
*/

CREATE VIEW [Present].[Provider_Active]
AS

SELECT MVIPersonSID
		,PatientICN
		,PatientSID
		,Sta3n
		,ChecklistID
		,Sta6a
		,DivisionName
		,ProviderSID
		,ProviderEDIPI
		,RelationshipStartDateTime AS RelationshipStartDate
		,RelationshipEndDateTime AS RelationshipEndDate
		,TeamRole
		,TeamSID
		,Team
		,PCP
		,MHTC
		,PrimaryProviderSID
		,PrimaryProviderEDIPI
		,StaffName
		,ActiveStaff
		,TerminationDateTime AS TerminationDate
		,AssociateProviderSID
		,StaffNameA
		,ActiveStaffA
		,TerminationDateA
		,AssociateProviderFlag
		,ProvRank_ICN
		,ProvRank_SID
		,TeamRank_ICN
		,TeamRank_SID
		,TeamType 
FROM [Common].[Providers] WITH (NOLOCK)
WHERE ActiveAny = 1