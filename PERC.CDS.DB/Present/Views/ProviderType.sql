



/*

2020-04-14	RAS	StaffSID in this view will now include Associate Providers from Present.Providers.  
				Present.Providers defines ProviderSID is either PrimaryProviderSID OR AssociateProviderSID if AssociateProviderFlag=1
20201202 - LM	Added ProviderEDIPI as provider identifier for Cerner sites

*/

CREATE VIEW [Present].[ProviderType]
AS

SELECT StaffSID, ProviderEDIPI, max(PCP) as PCP, max(MH) as MH
FROM (
	SELECT ProviderSID as StaffSID, ProviderEDIPI, PCP=1 , MH=0 
	FROM [Common].[Providers] WITH (NOLOCK)
	WHERE PCP=1
  UNION ALL
	SELECT StaffSID, ProviderEDIPI=NULL, PCP=0, MH=1 
	FROM [Present].[MHactivestaff] WITH (NOLOCK)
) as a
GROUP BY StaffSID,ProviderEDIPI