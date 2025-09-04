/*
Use this file to manage synonyms that refer to objects in CDWWork3

NAMING CONVENTION: Same schema and name as original object.

NOTE: Add new synonyms in the correct alphabetical order.

MODIFICATIONS:
	2023-12-07	D&A PERC Support - Adding reference to CDWWork3 SStaff SStaff_EHR, as requested by Shalini.

*/

CREATE SYNONYM [SStaff].[SStaff_EHR] FOR [$(CDWWork3)].[SStaff].[SStaff_EHR];
GO
CREATE SYNONYM [Dim].[Topography_EHR] FOR [$(CDWWork3)].[Dim].[Topography_EHR]
GO
