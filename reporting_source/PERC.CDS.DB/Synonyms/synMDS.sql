/*
Use this file to manage synonyms that refer to objects in Core that are managed by MDS system.

NAMING CONVENTION: Same schema and name as Core object (MDS schema).

NOTE: Add new synonyms in the correct alphabetical order for readability.
*/

-- Add a line of code for each synonym. External database references should be in SQL command
-- variable format (e.g., [$(OMHSP_PERC_Core)] and also need an existing reference in the project.


-------------------------------------------------------------------------------------------------
-- MDS -- Objects should have views in Core
-------------------------------------------------------------------------------------------------
-- CREATE SYNONYM [MDS].[Present_Provider] FOR [$(OMHSP_PERC_Core)].[MDS].[Present_Provider]
-- GO
CREATE SYNONYM [MDS].[MHIS_CombineData] FOR [$(OMHSP_PERC_Core)].[MDS].[MHIS_CombineData];
GO

CREATE SYNONYM [MDS].[Common_IVC_Cohort_Qtr] FOR [$(OMHSP_PERC_Core)].[MDS].[Common_IVC_Cohort_Qtr];
GO

CREATE SYNONYM [MDS].[Common_IVC_MHSEOC_Claim] FOR [$(OMHSP_PERC_Core)].[MDS].[Common_IVC_MHSEOC_Claim];
GO