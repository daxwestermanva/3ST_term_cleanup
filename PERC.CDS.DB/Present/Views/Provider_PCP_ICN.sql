





/*
Description: View includes most recent PCP assignment at unique patient level (MVIPersonSID/PatientICN).
Modifications:
	20200410 - RAS	Removed CASE statement for NULL StaffName (there are no NULL values in that field)
					Added ActiveStaffA to WHERE statement (active primary provider OR active associate provider)
					Added CASE statement to show associate provider name, where applicable
	20200414 - RAS	Replaced query using subquery and where statements with simpler code using new ranking fields in Present.Providers.
	20201202 - LM	Added ProviderEDIPI as provider identifier for Cerner sites
	20220310 - SG	Update AssociateProviderFlag='Y', instead of 1
Questions:
20200410 RAS Should we add primary provider information for flexibility?  If yes, should fields in other views (e.g., MHTC) also be updated so views are consistent?
*/


CREATE VIEW [Present].[Provider_PCP_ICN] 
AS

SELECT MVIPersonSID
	  ,PatientICN
	  ,ProviderSID
	  ,ProviderEDIPI
	  ,ProviderType='PCP'
	  ,StaffName = CASE WHEN AssociateProviderFlag=1 THEN StaffNameA ELSE StaffName END
	  ,Sta6a
	  ,DivisionName
	  ,ChecklistID
	  ,PatientSID
	  ,Sta3n
FROM [Common].[Providers] WITH (NOLOCK)
WHERE PCP=1 
	AND ProvRank_ICN=1