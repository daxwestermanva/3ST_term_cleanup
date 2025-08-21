/*******************************************************************************************************************************
Developer(s):	Kreisler, Craig
Create Date:	2022/08/17
Object Name:	Cerner References 
Description:	Script to create synonyms to the Cerner objects that exist in the Cerner hub system. The Cerner hub Cerner Views
                read from the OMHSP_PERC_Cerner spoke system.

REVISION LOG:

Version		Date			Developer					Description
1.0			2022/08/17		Kreisler, Craig				Initial script generation.
1.1         2023/05/25      Kreisler, Craig             Removed [Cerner].[DimVALocation] synonym. Source object has been deprecated. 
1.2         2023/06/21      Martins, Susana             Updated view list and repointed to Cerner rather than Core
1.2.1       2023/06/30      Bacani, Jason               Several Synonyms were pointed to deprecated tables and needed to point to the new views.
                                                        Synchronized CDS, Core, MDS, and Template version of this file across the board.
1.3         2023/09/18      Kreisler, Craig             Added Cerner.DimLab synonym. 
1.4         2025/1/16       Martins,Susana              Added Cerner.DimOrderCatalog
*******************************************************************************************************************************/
CREATE SYNONYM [Cerner].[DimActivityType] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwDimActivityType];
GO
CREATE SYNONYM [Cerner].[DimAppointmentStatus] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwDimAppointmentStatus];
GO
CREATE SYNONYM [Cerner].[DimAppointmentType] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwDimAppointmentType];
GO
CREATE SYNONYM [Cerner].[DimDrug] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[DimDrug];
GO
CREATE SYNONYM [Cerner].[DimDSTSpans] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[DimDSTSpans];
GO
CREATE SYNONYM [Cerner].[DimLab] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[DimLab];
GO
CREATE SYNONYM [Cerner].[DimLocations] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[DimLocations];
GO
CREATE SYNONYM [Cerner].[DimMedOrderCatalog] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[DimMedOrderCatalog];
GO
CREATE SYNONYM [Cerner].[DimNomenclature] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwDimNomenclature];
GO
CREATE SYNONYM [Cerner].[DimOrderCatalog] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[DimOrderCatalog];
GO
CREATE SYNONYM [Cerner].[DimPowerFormNoteTitle] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwDimPowerFormNoteTitle];
GO
CREATE SYNONYM [Cerner].[DimSpecialty] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwDimSpecialty];
GO
CREATE SYNONYM [Cerner].[DimStopCode] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwDimStopCode];
GO
CREATE SYNONYM [Cerner].[DimTimeZone] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[DimTimeZone];
GO
CREATE SYNONYM [Cerner].[EncMillEncounter] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[EncMillEncounter];
GO
CREATE SYNONYM [Cerner].[FactAppointment] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactAppointment];
GO
CREATE SYNONYM [Cerner].[FactBHL] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactBHL];
GO
CREATE SYNONYM [Cerner].[FactDiagnosis] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactDiagnosis];
GO
CREATE SYNONYM [Cerner].[FactImmunization] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactImmunization];
GO
CREATE SYNONYM [Cerner].[FactInpatient] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactInpatient];
GO
CREATE SYNONYM [Cerner].[FactInpatientSpecialtyTransfer] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactInpatientSpecialtyTransfer];
GO
CREATE SYNONYM [Cerner].[FactLabResult] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactLabResult];
GO
CREATE SYNONYM [Cerner].[FactNoteTitle] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactNoteTitle];
GO
CREATE SYNONYM [Cerner].[FactPatientContactInfo] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPatientContactInfo];
GO
CREATE SYNONYM [Cerner].[FactPatientDemographic] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPatientDemographic];
GO
CREATE SYNONYM [Cerner].[FactPatientNextOfKin] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPatientNextOfKin];
GO
CREATE SYNONYM [Cerner].[FactPatientRecordFlag] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPatientRecordFlag];
GO
CREATE SYNONYM [Cerner].[FactPharmacyBCMA] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyBCMA];
GO
CREATE SYNONYM [Cerner].[FactPharmacyClinicOrderDispensed] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyClinicOrderDispensed];
GO
CREATE SYNONYM [Cerner].[FactPharmacyInpatientDispensed] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyInpatientDispensed];
GO
CREATE SYNONYM [Cerner].[FactPharmacyInpatientOrder] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyInpatientOrder];
GO
CREATE SYNONYM [Cerner].[FactPharmacyNonVAMedOrder] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyNonVAMedOrder];
GO
CREATE SYNONYM [Cerner].[FactPharmacyOutpatientDispensed] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyOutpatientDispensed];
GO
CREATE SYNONYM [Cerner].[FactPharmacyOutpatientOrder] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyOutpatientOrder];
GO
CREATE SYNONYM [Cerner].[FactPharmacyOutpatientOrderDispense] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPharmacyOutpatientOrderDispense];
GO
CREATE SYNONYM [Cerner].[FactPowerForm] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactPowerForm];
GO
CREATE SYNONYM [Cerner].[FactProcedure] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactProcedure];
GO
CREATE SYNONYM [Cerner].[FactReferral] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactReferral];
GO
CREATE SYNONYM [Cerner].[FactSocialHistory] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactSocialHistory];
GO
CREATE SYNONYM [Cerner].[FactStaffDemographic] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactStaffDemographic];
GO
CREATE SYNONYM [Cerner].[FactStaffProviderType] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactStaffProviderType];
GO
CREATE SYNONYM [Cerner].[FactUtilizationInpatientVisit] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[vwFactUtilizationInpatientVisit];
GO
CREATE SYNONYM [Cerner].[FactUtilizationOutpatient] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactUtilizationOutpatient];
GO
CREATE SYNONYM [Cerner].[FactUtilizationOutpatientWorkload] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactUtilizationOutpatientWorkload];
GO
CREATE SYNONYM [Cerner].[FactUtilizationStopCode] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactUtilizationStopCode];
GO
CREATE SYNONYM [Cerner].[FactUtilizationWorkload_002] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactUtilizationWorkload_002];
GO
CREATE SYNONYM [Cerner].[FactVitalSign] FOR [$(OMHSP_PERC_Cerner)].[MillCDS].[FactVitalSign];
GO
CREATE SYNONYM [Cerner].[vwConfigMaintenanceJobs] FOR [$(OMHSP_PERC_Cerner)].[App].[vwConfigMaintenanceJobs];
GO
