/*
Use this file to manage synonyms that refer to objects generated in Core
or views in Core for SPV and SPV2 (that require logic, not just synonym)

NAMING CONVENTION: Same schema and name as original object in Core.

NOTE: Add new synonyms in the correct alphabetical order.

MODIFICATIONS:
	2022-05-06	RAS	Updated to Core objects and Core SPV/SPV2 views.
	2024-05-13  CW  Adding CommunityCare Overdose
	2024-09-16  CW  Adding CommunityCare Emergency
	2024-10-23 AER	Fips config
	2025-03-12  GC  Added Common.Provider and Common.ProviderHistory tables
*/

--------------------------------------------------------------------------------------------------------------
-- Core objects
--------------------------------------------------------------------------------------------------------------
CREATE SYNONYM [Log].[ExecutionBeginCore] FOR [$(OMHSP_PERC_Core)].[Log].[ExecutionBeginCore]
GO
CREATE SYNONYM [Log].[ExecutionEndCore] FOR [$(OMHSP_PERC_Core)].[Log].[ExecutionEndCore]
GO
CREATE SYNONYM [Log].[MessageCore] FOR [$(OMHSP_PERC_Core)].[Log].[MessageCore]
GO
CREATE SYNONYM [Log].[PublishTableCore] FOR [$(OMHSP_PERC_Core)].[Log].[PublishTableCore]
GO
--CREATE SYNONYM [Log].[ExecutionLog] FOR [$(OMHSP_PERC_Core)].[Log].[ExecutionLog]
--GO
--CREATE SYNONYM [Log].[MessageLog] FOR [$(OMHSP_PERC_Core)].[Log].[MessageLog]
--GO
--CREATE SYNONYM [Log].[PublishedTableLog] FOR [$(OMHSP_PERC_Core)].[Log].[PublishedTableLog]
--GO
CREATE SYNONYM [Maintenance].[PublishTableCore] FOR [$(OMHSP_PERC_Core)].[Maintenance].[PublishTableCore]
GO
CREATE SYNONYM [Maintenance].[RefreshAllViewsCore] FOR [$(OMHSP_PERC_Core)].[Maintenance].[RefreshAllViewsCore]
GO
CREATE SYNONYM [Tool].[ObjectSearchCore] FOR [$(OMHSP_PERC_Core)].[Tool].[ObjectSearchCore]
GO
CREATE SYNONYM [VBA].[MST_Claims_Events] FOR [$(OMHSP_PERC_Core)].[VBA].[MST_Claims_Events]
GO
CREATE SYNONYM [Config].[FIPS_County] FOR [$(OMHSP_PERC_Core)].[Config].[FIPS_County];
GO
CREATE SYNONYM [Common].[Providers] FOR  [$(OMHSP_PERC_Core)].[Common].[Providers]
GO
CREATE SYNONYM [Common].[ProviderTeamHistory] FOR [$(OMHSP_PERC_Core)].[Common].[ProviderTeamHistory];
GO

--------------------------------------------------------------------------------------------------------------
-- PLATFORM Views
--------------------------------------------------------------------------------------------------------------
CREATE SYNONYM [Platform].[Core_dependency_detail] FOR [$(OMHSP_PERC_Core)].[Platform].[Core_dependency_detail]
GO
CREATE SYNONYM [Platform].[Core_changeset_impact] FOR [$(OMHSP_PERC_Core)].[Platform].[Core_changeset_impact]
GO
CREATE SYNONYM [Platform].[Core_changeset_detail] FOR [$(OMHSP_PERC_Core)].[Platform].[Core_changeset_detail]
GO
CREATE SYNONYM [Platform].[Core_changeset_content] FOR [$(OMHSP_PERC_Core)].[Platform].[Core_changeset_content]
GO
CREATE SYNONYM [Platform].[Core_changeset] FOR [$(OMHSP_PERC_Core)].[Platform].[Core_changeset]
GO

--------------------------------------------------------------------------------------------------------------
-- SPV & SPV2 Views
--------------------------------------------------------------------------------------------------------------
CREATE SYNONYM [CommunityCare].[ODUniqueEpisode] FOR [$(OMHSP_PERC_Core)].[CommunityCare].[ODUniqueEpisode]
GO
CREATE SYNONYM [SPV].[SPatient_SPatient] FOR [$(OMHSP_PERC_Core)].[SPV].[SPatient_SPatient]
GO
CREATE SYNONYM [SPatient].[SPatientBirthSex] FOR [$(OMHSP_PERC_Core)].[SPV].[SPatient_SPatientBirthSex]
GO
CREATE SYNONYM [CommunityCare].[EmergencyVisit] FOR [$(OMHSP_PERC_Core)].[CommunityCare].[EmergencyVisit]
GO


