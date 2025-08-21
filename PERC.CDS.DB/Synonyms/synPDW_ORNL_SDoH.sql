/*
Use this file to manage synonyms that refer to objects in PDW: OMHSP_PERC_PDW


NOTE: Add new synonyms in the correct alphabetical order.

MODIFICATIONS:
	YYYY-MM-DD	ABC - Comments
	2024-10-24	JEB	- Initial creation With Priority REACH VET needed ORNL SDoH Synonyms
	2025-02-11  AER - Add new REACH VET  ORNL SDoH Synonyms
*/
CREATE SYNONYM [PDW].[ORNL_SDoH_Education_County] FOR [$(OMHSP_PERC_PDW)].[App].[ORNL_SDoH_Education_County]				
GO
CREATE SYNONYM [PDW].[ORNL_SDoH_Elevation_County] FOR [$(OMHSP_PERC_PDW)].[App].[ORNL_SDoH_Elevation_County]				
GO
CREATE SYNONYM [PDW].[ORNL_SDoH_Food_Insecurity_County] FOR [$(OMHSP_PERC_PDW)].[App].[ORNL_SDoH_Food_Insecurity_County]				
GO
CREATE SYNONYM [PDW].[ORNL_SDoH_Income_County] FOR [$(OMHSP_PERC_PDW)].[App].[ORNL_SDoH_Income_County]				
GO
CREATE SYNONYM [PDW].[ORNL_SDoH_RUCC_County] FOR [$(OMHSP_PERC_PDW)].[App].[ORNL_SDoH_RUCC_County]				
GO
CREATE SYNONYM [PDW].[ORNL_SDoH_Unemployment_County] FOR [$(OMHSP_PERC_PDW)].[App].[ORNL_SDoH_Unemployment_County]				
GO