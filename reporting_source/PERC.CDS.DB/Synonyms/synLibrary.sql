/*
Use this file to manage synonyms that refer to objects in Core that are managed by Library system.

NAMING CONVENTION: Same schema and name as Core object (Library schema).

NOTE: Add new synonyms in the correct alphabetical order for readability.
*/

-- Add a line of code for each synonym. External database references should be in SQL command
-- variable format (e.g., [$(OMHSP_PERC_Core)] and also need an existing reference in the project.

-------------------------------------------------------------------------------------------------
-- Library -- Objects should have views in Core
-------------------------------------------------------------------------------------------------
CREATE SYNONYM [Library].[XLA_XLA2_Metadata] FOR [$(OMHSP_PERC_Core)].[Library].[XLA_XLA2_Metadata];
GO
