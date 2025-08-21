/*
Use this file to manage synonyms that refer to objects in Core that are managed by XLA system.

NAMING CONVENTION: Same schema and name as Core object (XLA schema).

NOTE: Add new synonyms in the correct alphabetical order for readability.
*/

-- Add a line of code for each synonym. External database references should be in SQL command
-- variable format (e.g., [$(OMHSP_PERC_Core)] and also need an existing reference in the project.

-------------------------------------------------------------------------------------------------
-- XLA -- Objects should have views in Core
-------------------------------------------------------------------------------------------------
-- COMMON XLA SYNONYMS
CREATE SYNONYM [XLA].[Dim_CodeSystem] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_CodeSystem];
GO
CREATE SYNONYM [XLA].[Dim_CohortNumber] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_CohortNumber];
GO
CREATE SYNONYM [XLA].[Dim_Dataset] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_Dataset];
GO
CREATE SYNONYM [XLA].[Dim_Domain] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_Domain];
GO
CREATE SYNONYM [XLA].[Dim_GroupBy] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_GroupBy];
GO
CREATE SYNONYM [XLA].[Dim_LogicStructure] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_LogicStructure];
GO
CREATE SYNONYM [XLA].[Dim_OutputType] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_OutputType];
GO
CREATE SYNONYM [XLA].[Dim_TableName] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_TableName];
GO
CREATE SYNONYM [XLA].[Dim_TableType] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_TableType];
GO
CREATE SYNONYM [XLA].[Dim_Timeframe] FOR [$(OMHSP_PERC_Core)].[XLA].[Dim_Timeframe];
GO
CREATE SYNONYM [XLA].[Lib_Concept] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_Concept]
GO
CREATE SYNONYM [XLA].[Lib_ValueMatchID] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_ValueMatchID]
GO

-- XLA SYNONYMS FOR CDS
CREATE SYNONYM [XLA].[Lib_SuperSets_ALEX] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SuperSets_ALEX]
GO
CREATE SYNONYM [XLA].[Lib_SetValues_ALEX] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SetValues_ALEX]
GO
CREATE SYNONYM [XLA].[Lib_SuperSets_CDS] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SuperSets_CDS]
GO
CREATE SYNONYM [XLA].[Lib_SetValues_CDS] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SetValues_CDS]
GO
CREATE SYNONYM [XLA].[Lib_SetValues_RiskNightly] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SetValues_RiskNightly]
GO
CREATE SYNONYM [XLA].[Lib_SetValues_RiskMonthly] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SetValues_RiskMonthly]
GO
CREATE SYNONYM [XLA].[MDS_eTM] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS_eTM]
GO
CREATE SYNONYM [XLA].[MHIS_Cohort] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Cohort];
GO
CREATE SYNONYM [XLA].[MHIS_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Summary];
GO
CREATE SYNONYM [XLA].[PSR_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[PSR_Unit];
GO
CREATE SYNONYM [XLA].[PSR_UnitProviderType] FOR [$(OMHSP_PERC_Core)].[XLA].[PSR_UnitProviderType];
GO
CREATE SYNONYM [XLA].[RiskMonthly_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[RiskMonthly_Summary];
GO
CREATE SYNONYM [XLA].[RiskNightly_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[RiskNightly_Summary];
GO
CREATE SYNONYM [XLA].[RiskMonthly_Instance] FOR [$(OMHSP_PERC_Core)].[XLA].[RiskMonthly_Instance];
GO
CREATE SYNONYM [XLA].[RiskNightly_Instance] FOR [$(OMHSP_PERC_Core)].[XLA].[RiskNightly_Instance];


-- XLA SYNONYMS FOR MDS
--CREATE SYNONYM [XLA].[Lib_SuperSets] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SuperSets_MDS]
--GO
--CREATE SYNONYM [XLA].[Lib_SetValues] FOR [$(OMHSP_PERC_Core)].[XLA].[Lib_SetValues_MDS]
--GO
--CREATE SYNONYM [XLA].[IMF_Cohort] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Cohort]
--GO
--CREATE SYNONYM [XLA].[MDS1_Cohort] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Cohort]
--GO
--CREATE SYNONYM [XLA].[MDS_eTM] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS_eTM]
--GO
--CREATE SYNONYM [XLA].[MHIS_Cohort] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Cohort];
--GO
--CREATE SYNONYM [XLA].[MHIS_Crosswalk] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS_Crosswalk];
--GO
--CREATE SYNONYM [XLA].[MHIS_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Summary];
--GO
--CREATE SYNONYM [XLA].[MHIS_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Unit];
--GO
--CREATE SYNONYM [XLA].[MHIS2_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS2_Summary];
--GO
--CREATE SYNONYM [XLA].[MHIS2_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS2_Unit];
--GO
--CREATE SYNONYM [XLA].[MHIS3_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS3_Summary];
--GO
--CREATE SYNONYM [XLA].[MHIS3_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS3_Unit];
--GO
--CREATE SYNONYM [XLA].[MHISNew_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1New_Summary];
--GO
--CREATE SYNONYM [XLA].[MHISNew_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1New_Unit];
--GO
--CREATE SYNONYM [XLA].[MHIS2New_Summary] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS2New_Summary];
--GO
--CREATE SYNONYM [XLA].[MHIS2New_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS2New_Unit];
--GO
--CREATE SYNONYM [XLA].[MHIS_Unit_FUHTemp] FOR [$(OMHSP_PERC_Core)].[XLA].[MDS1_Unit_FUHTemp];
--GO
--CREATE SYNONYM [XLA].[MHOC_Crosswalk] FOR [$(OMHSP_PERC_Core)].[XLA].[MHOC_Crosswalk];
--GO
--CREATE SYNONYM [XLA].[MHOC_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[MHOC_Unit];
--GO
--CREATE SYNONYM [XLA].[MHOC_ProviderTypeVisit] FOR [$(OMHSP_PERC_Core)].[XLA].[MHOC_ProviderTypeVisit];
--GO
--CREATE SYNONYM [XLA].[PSR_Unit] FOR [$(OMHSP_PERC_Core)].[XLA].[PSR_Unit];
--GO
--CREATE SYNONYM [XLA].[PSR_UnitProviderType] FOR [$(OMHSP_PERC_Core)].[XLA].[PSR_UnitProviderType];
--GO

