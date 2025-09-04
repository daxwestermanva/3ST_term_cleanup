







/*
Description: View includes most recent MHTC assignment at unique patient level (MVIPersonSID/PatientICN).
Modifications:
	20200414 - RAS	Removed CASE statement for NULL StaffName (there are no NULL values in that field).
					Replaced query using subquery and where statements with simpler code using new ranking fields in Present.Providers.
	20201202 - LM	Added ProviderEDIPI as provider identifier for Cerner sites
*/

CREATE VIEW [Present].[Provider_MHTC_ICN] AS

SELECT MVIPersonSID
	  ,PatientICN
	  ,ProviderSID
	  ,ProviderEDIPI
	  ,Sta6a
	  ,ProviderType ='MHTC'
	  ,DivisionName
	  ,TeamRole
	  ,StaffName
	  ,ChecklistID
	  ,PatientSID
	  ,Sta3n
FROM [Common].[Providers] WITH (NOLOCK)
WHERE MHTC=1
	AND ProvRank_ICN=1