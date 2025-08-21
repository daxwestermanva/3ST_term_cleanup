


/*******************************************************************************************************************************
Developer(s)	: Gupta, Shalini
Create Date		: 01/07/2021
Object Name		: [LookUp].[Stapa]
Description		: Cerner STAPA, OrganizationName with  ADMParent_FCDM 

REVISON LOG		:

Version		Date			Developer				Description
1.0			01/07/2021		Gupta, Shalini			Initial Build
1.1         04/29/2021      Gupta, Shalini          Update stapaPa reference
1.2			08/15/2022		Alston, Steven			Updated source of facility location from [MillCDS].[DimVALocation] to [MillCDS].[DimLocations]
													New table includes DoD location data					
1.3         06/17/2024      Gupta, Shalini          Updated the join [Cerner].[DimLocations] and [LookUp].[ChecklistID] on StaPa
******************************************************************************************************************************/
CREATE   VIEW [LookUp].[Stapa]

/*******************************************************************************************************************************
Description : Cerner STAPA, OrganizationName with  ADMParent_FCDM 
              139 AdminParent (ChecklistID)
*******************************************************************************************************************************/

AS 
 
	SELECT DISTINCT
		dloc.Visn
		,dloc.STAPA 
		,dloc.OrganizationName
		,clst.ADMPARENT_FCDM
		,clst.Facility      
	FROM [Cerner].[DimLocations] AS dloc WITH (NOLOCK)
	INNER JOIN [LookUp].[ChecklistID]  AS clst WITH (NOLOCK) ON dloc.STAPA = clst.Stapa
	WHERE dloc.STAPA IS NOT NULL AND SUBSTRING(dloc.OrganizationName, 1, CHARINDEX(' ', dloc.OrganizationName) - 1) = dloc.STAPA 
	AND (dloc.OrganizationName NOT LIKE '%Oncology%' AND OrganizationName NOT LIKE '%Community%' AND OrganizationName NOT LIKE '%Occupational%')

--   select * from [LookUp].[Stapa] 
--   where stapa in ('640','668','663','687','692','757','653','531')
--   order by StaPA 
--  select *  FROM MillCDS.DimVALocation where stapa ='757' order by sta6a