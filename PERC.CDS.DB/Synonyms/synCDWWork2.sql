/*
Use this file to manage synonyms that refer to objects in CDWWork2

NAMING CONVENTION: Same schema and name as original object.

NOTE: Add new synonyms in the correct alphabetical order.

MODIFICATIONS:
	2022-05-06	RAS	Created file with all synonyms. Pointed Mill objects to CDWWork2, then evaluated what broke in dependencies.
					Commented out items that need to use SPV2 or SPV -- these will persist as views until moved to Core.
	2022-06-07	RAS	Pointed synonyms to Core except where build failed (objects used in views could not be changed to point to Core).
	2022-06-16	JEB	Added new synonym to Core for [NDimMill].[AppointmentOption] per request from Craig
	2022-06-22	JEB Added new Synonym to Core for [NDimMill].[OrganizationTypeRelation], per request from Steve A
	2022-07-07	RAS	Replaced remaining view objects with synonyms to Core (SPatient.SPatient, EncMill.Encounter, 
					NDimMill.CatalogItemRelationship, NDimMill.CodeValue, NDimMill.CodeValueGroup, NDimMill.CodeValueSet)
	2022-08-04	JEB Making this the 'master' file and copying it over to all sister systems. Also alphabetized. Centalization to one file will be done at a later dat (if it's possible, that is)
	2022-08-18	RAS	Branched and renamed this file to be specifically for CDWWork2 references.
	2023-02-07	RAS	Replaced OMHSP_PERC_Core reference with direct CDWWork2 reference.
*/

CREATE SYNONYM [AllergyMill].[AdverseReaction] FOR [$(CDWWork2)].[AllergyMill].[AdverseReaction];
GO
CREATE SYNONYM [AllergyMill].[PersonAllergy] FOR [$(CDWWork2)].[AllergyMill].[PersonAllergy];
GO
CREATE SYNONYM [BillingMill].[BilledCharge] FOR [$(CDWWork2)].[BillingMill].[BilledCharge];
GO
CREATE SYNONYM [BillingMill].[BillEncounter] FOR [$(CDWWork2)].[BillingMill].[BillEncounter];
GO
CREATE SYNONYM [BillingMill].[ChargeItem] FOR [$(CDWWork2)].[BillingMill].[ChargeItem];
GO
CREATE SYNONYM [BillingMill].[ChargeModification] FOR [$(CDWWork2)].[BillingMill].[ChargeModification];
GO
CREATE SYNONYM [BillingMill].[GeneralLedger] FOR [$(CDWWork2)].[BillingMill].[GeneralLedger];
GO
CREATE SYNONYM [BloodBankMill].[BBProduct] FOR [$(CDWWork2)].[BloodBankMill].[BBProduct];
GO
CREATE SYNONYM [BloodBankMill].[BloodProduct] FOR [$(CDWWork2)].[BloodBankMill].[BloodProduct];
GO
CREATE SYNONYM [BloodBankMill].[PersonBloodgroup] FOR [$(CDWWork2)].[BloodBankMill].[PersonBloodgroup];
GO
CREATE SYNONYM [BloodBankMill].[PersonBloodgroupResult] FOR [$(CDWWork2)].[BloodBankMill].[PersonBloodgroupResult];
GO
CREATE SYNONYM [BloodBankMill].[ProductEvent] FOR [$(CDWWork2)].[BloodBankMill].[ProductEvent];
GO
CREATE SYNONYM [BloodBankMill].[Transfusion] FOR [$(CDWWork2)].[BloodBankMill].[Transfusion];
GO
CREATE SYNONYM [CareChartMill].[DocFormActivity] FOR [$(CDWWork2)].[CareChartMill].[DocFormActivity];
GO
CREATE SYNONYM [CareChartMill].[SocialHistoryAction] FOR [$(CDWWork2)].[CareChartMill].[SocialHistoryAction];
GO
CREATE SYNONYM [CareChartMill].[SocialHistoryActivity] FOR [$(CDWWork2)].[CareChartMill].[SocialHistoryActivity];
GO
CREATE SYNONYM [CareChartMill].[SocialHistoryActivityResponse] FOR [$(CDWWork2)].[CareChartMill].[SocialHistoryActivityResponse];
GO
CREATE SYNONYM [CareChartMill].[SocialHistoryResponse] FOR [$(CDWWork2)].[CareChartMill].[SocialHistoryResponse];
GO
CREATE SYNONYM [ClinicalEventMill].[CELabSpecimen] FOR [$(CDWWork2)].[ClinicalEventMill].[CELabSpecimen];
GO
CREATE SYNONYM [ClinicalEventMill].[CEPharmacy] FOR [$(CDWWork2)].[ClinicalEventMill].[CEPharmacy];
GO
CREATE SYNONYM [ClinicalEventMill].[CEPharmacyDetail] FOR [$(CDWWork2)].[ClinicalEventMill].[CEPharmacyDetail];
GO
CREATE SYNONYM [ClinicalEventMill].[CEPharmacyIdentifier] FOR [$(CDWWork2)].[ClinicalEventMill].[CEPharmacyIdentifier];
GO
CREATE SYNONYM [ClinicalEventMill].[CEReference] FOR [$(CDWWork2)].[ClinicalEventMill].[CEReference];
GO
CREATE SYNONYM [ClinicalEventMill].[CEReferenceDetail] FOR [$(CDWWork2)].[ClinicalEventMill].[CEReferenceDetail];
GO
CREATE SYNONYM [ClinicalEventMill].[CEResultCode] FOR [$(CDWWork2)].[ClinicalEventMill].[CEResultCode];
GO
CREATE SYNONYM [ClinicalEventMill].[CEResultDate] FOR [$(CDWWork2)].[ClinicalEventMill].[CEResultDate];
GO
CREATE SYNONYM [ClinicalEventMill].[CEStaff] FOR [$(CDWWork2)].[ClinicalEventMill].[CEStaff];
GO
CREATE SYNONYM [ClinicalEventMill].[ClinicalEvent] FOR [$(CDWWork2)].[ClinicalEventMill].[ClinicalEvent]
GO
CREATE SYNONYM [ClinicalEventMill].[EventTrack] FOR [$(CDWWork2)].[ClinicalEventMill].[EventTrack];
GO
CREATE SYNONYM [EncMill].[Encounter] FOR [$(CDWWork2)].[EncMill].[Encounter];
GO
CREATE SYNONYM [EncMill].[EncounterAlias] FOR [$(CDWWork2)].[EncMill].[EncounterAlias];
GO
CREATE SYNONYM [EncMill].[EncounterCode] FOR [$(CDWWork2)].[EncMill].[EncounterCode];
GO
CREATE SYNONYM [EncMill].[EncounterDetail] FOR [$(CDWWork2)].[EncMill].[EncounterDetail];
GO
CREATE SYNONYM [EncMill].[EncounterDiagnosis] FOR [$(CDWWork2)].[EncMill].[EncounterDiagnosis];
GO
CREATE SYNONYM [EncMill].[EncounterGrouping] FOR [$(CDWWork2)].[EncMill].[EncounterGrouping];
GO
CREATE SYNONYM [EncMill].[EncounterHPEligibilityBenefit] FOR [$(CDWWork2)].[EncMill].[EncounterHPEligibilityBenefit];
GO
CREATE SYNONYM [EncMill].[EncounterLocationHistory] FOR [$(CDWWork2)].[EncMill].[EncounterLocationHistory];
GO
CREATE SYNONYM [EncMill].[EncounterProcedureDetail] FOR [$(CDWWork2)].[EncMill].[EncounterProcedureDetail];
GO
CREATE SYNONYM [EncMill].[EncounterStaff] FOR [$(CDWWork2)].[EncMill].[EncounterStaff];
GO
CREATE SYNONYM [EncMill].[ProcedureStaffRelation] FOR [$(CDWWork2)].[EncMill].[ProcedureStaffRelation];
GO
CREATE SYNONYM [EncMill].[RecordCompliance] FOR [$(CDWWork2)].[EncMill].[RecordCompliance];
GO
CREATE SYNONYM [EncMill].[TrackingCheckIn] FOR [$(CDWWork2)].[EncMill].[TrackingCheckIn];
GO
CREATE SYNONYM [EncMill].[TrackingEvent] FOR [$(CDWWork2)].[EncMill].[TrackingEvent];
GO
CREATE SYNONYM [EncMill].[TrackingItem] FOR [$(CDWWork2)].[EncMill].[TrackingItem];
GO
CREATE SYNONYM [EncMill].[TrackingLocator] FOR [$(CDWWork2)].[EncMill].[TrackingLocator];
GO
CREATE SYNONYM [MAEMill].[MedAdministrationEvent] FOR [$(CDWWork2)].[MAEMill].[MedAdministrationEvent];
GO
CREATE SYNONYM [MultumMill].[DrugCategory] FOR [$(CDWWork2)].[MultumMill].[DrugCategory];
GO
CREATE SYNONYM [MultumMill].[MedCategoryCrossReference] FOR [$(CDWWork2)].[MultumMill].[MedCategoryCrossReference];
GO
CREATE SYNONYM [MultumMill].[MedCrossReference] FOR [$(CDWWork2)].[MultumMill].[MedCrossReference];
GO
CREATE SYNONYM [MultumMill].[MedProductDescription] FOR [$(CDWWork2)].[MultumMill].[MedProductDescription];
GO
CREATE SYNONYM [MultumMill].[MMDCSynonym] FOR [$(CDWWork2)].[MultumMill].[MMDCSynonym];
GO
CREATE SYNONYM [MultumMill].[MultumDrugNameMap] FOR [$(CDWWork2)].[MultumMill].[MultumDrugNameMap];
GO
CREATE SYNONYM [NDimMill].[Address] FOR [$(CDWWork2)].[NDimMill].[Address];
GO
CREATE SYNONYM [NDimMill].[AppointmentOption] FOR [$(CDWWork2)].[NDimMill].[AppointmentOption];
GO
CREATE SYNONYM [NDimMill].[AttributeLocationRelation] FOR [$(CDWWork2)].[NDimMill].[AttributeLocationRelation];
GO
CREATE SYNONYM [NDimMill].[BillItem] FOR [$(CDWWork2)].[NDimMill].[BillItem];
GO
CREATE SYNONYM [NDimMill].[BillItemModifier] FOR [$(CDWWork2)].[NDimMill].[BillItemModifier];
GO
CREATE SYNONYM [NDimMill].[BillTransactionAlias] FOR [$(CDWWork2)].[NDimMill].[BillTransactionAlias];
GO
CREATE SYNONYM [NDimMill].[CareChartFormDefinition] FOR [$(CDWWork2)].[NDimMill].[CareChartFormDefinition];
GO
CREATE SYNONYM [NDimMill].[CareChartFormSection] FOR [$(CDWWork2)].[NDimMill].[CareChartFormSection];
GO
CREATE SYNONYM [NDimMill].[CatalogItemRelationship] FOR [$(CDWWork2)].[NDimMill].[CatalogItemRelationship];
GO
CREATE SYNONYM [NDimMill].[CodeValue] FOR [$(CDWWork2)].[NDimMill].[CodeValue];
GO
CREATE SYNONYM [NDimMill].[CodeValueGroup] FOR [$(CDWWork2)].[NDimMill].[CodeValueGroup];
GO
CREATE SYNONYM [NDimMill].[CodeValueOutbound] FOR [$(CDWWork2)].[NDimMill].[CodeValueOutbound];
GO
CREATE SYNONYM [NDimMill].[CodeValueSet] FOR [$(CDWWork2)].[NDimMill].[CodeValueSet];
GO
CREATE SYNONYM [NDimMill].[DataManagementFlags] FOR [$(CDWWork2)].[NDimMill].[DataManagementFlags];
GO
CREATE SYNONYM [NDimMill].[DCPFormsActivityComp] FOR [$(CDWWork2)].[NDimMill].[DCPFormsActivityComp];
GO
CREATE SYNONYM [NDimMill].[EventCode] FOR [$(CDWWork2)].[NDimMill].[EventCode];
GO
CREATE SYNONYM [NDimMill].[EventSet] FOR [$(CDWWork2)].[NDimMill].[EventSet];
GO
CREATE SYNONYM [NDimMill].[EventSetCode] FOR [$(CDWWork2)].[NDimMill].[EventSetCode];
GO
CREATE SYNONYM [NDimMill].[EventSetCodeRelation] FOR [$(CDWWork2)].[NDimMill].[EventSetCodeRelation];
GO
CREATE SYNONYM [NDimMill].[Facility] FOR [$(CDWWork2)].[NDimMill].[Facility];
GO
CREATE SYNONYM [NDimMill].[FacilityLocation] FOR [$(CDWWork2)].[NDimMill].[FacilityLocation];
GO
CREATE SYNONYM [NDimMill].[Medication] FOR [$(CDWWork2)].[NDimMill].[Medication];
GO
CREATE SYNONYM [NDimMill].[MedOrderDefault] FOR [$(CDWWork2)].[NDimMill].[MedOrderDefault];
GO
CREATE SYNONYM [NDimMill].[MedProductInfo] FOR [$(CDWWork2)].[NDimMill].[MedProductInfo];
GO
CREATE SYNONYM [NDimMill].[Nomenclature] FOR [$(CDWWork2)].[NDimMill].[Nomenclature];
GO
CREATE SYNONYM [NDimMill].[OrderCatalog] FOR [$(CDWWork2)].[NDimMill].[OrderCatalog];
GO
CREATE SYNONYM [NDimMill].[OrderCatalogSynonym] FOR [$(CDWWork2)].[NDimMill].[OrderCatalogSynonym];
GO
CREATE SYNONYM [NDimMill].[OrderFormatDetail] FOR [$(CDWWork2)].[NDimMill].[OrderFormatDetail];
GO
CREATE SYNONYM [NDimMill].[OrderPreferenceCategory] FOR [$(CDWWork2)].[NDimMill].[OrderPreferenceCategory];
GO
CREATE SYNONYM [NDimMill].[OrderPreferenceList] FOR [$(CDWWork2)].[NDimMill].[OrderPreferenceList];
GO
CREATE SYNONYM [NDimMill].[OrganizationAlias] FOR [$(CDWWork2)].[NDimMill].[OrganizationAlias];
GO
CREATE SYNONYM [NDimMill].[OrganizationName] FOR [$(CDWWork2)].[NDimMill].[OrganizationName];
GO
CREATE SYNONYM [NDimMill].[OrganizationService] FOR [$(CDWWork2)].[NDimMill].[OrganizationService];
GO
CREATE SYNONYM [NDimMill].[OrganizationTypeRelation] FOR [$(CDWWork2)].[NDimMill].[OrganizationTypeRelation];
GO
CREATE SYNONYM [NDimMill].[ParentItemManufacturer] FOR [$(CDWWork2)].[NDimMill].[ParentItemManufacturer];
GO
CREATE SYNONYM [NDimMill].[ParentItemPackageType] FOR [$(CDWWork2)].[NDimMill].[ParentItemPackageType];
GO
CREATE SYNONYM [NDimMill].[PriceSchedule] FOR [$(CDWWork2)].[NDimMill].[PriceSchedule];
GO
CREATE SYNONYM [NDimMill].[TimeZone] FOR [$(CDWWork2)].[NDimMill].[TimeZone];
GO
CREATE SYNONYM [NDimMill].[TrackEvent] FOR [$(CDWWork2)].[NDimMill].[TrackEvent];
GO
CREATE SYNONYM [OrderMill].[OrderActionDetail] FOR [$(CDWWork2)].[OrderMill].[OrderActionDetail];
GO
CREATE SYNONYM [OrderMill].[OrderComplianceDetail] FOR [$(CDWWork2)].[OrderMill].[OrderComplianceDetail];
GO
CREATE SYNONYM [OrderMill].[OrderDetail] FOR [$(CDWWork2)].[OrderMill].[OrderDetail];
GO
CREATE SYNONYM [OrderMill].[OrderIngredient] FOR [$(CDWWork2)].[OrderMill].[OrderIngredient];
GO
CREATE SYNONYM [OrderMill].[OrderRelation] FOR [$(CDWWork2)].[OrderMill].[OrderRelation];
GO
CREATE SYNONYM [OrderMill].[PersonOrder] FOR [$(CDWWork2)].[OrderMill].[PersonOrder];
GO
CREATE SYNONYM [OrderMill].[TaskActivity] FOR [$(CDWWork2)].[OrderMill].[TaskActivity];
GO
CREATE SYNONYM [PathologyMill].[AccessionOrder] FOR [$(CDWWork2)].[PathologyMill].[AccessionOrder];
GO
CREATE SYNONYM [PharmacyMill].[DispenseDetail] FOR [$(CDWWork2)].[PharmacyMill].[DispenseDetail];
GO
CREATE SYNONYM [PharmacyMill].[DispenseHistory] FOR [$(CDWWork2)].[PharmacyMill].[DispenseHistory];
GO
CREATE SYNONYM [PharmacyMill].[DispenseHistoryMed] FOR [$(CDWWork2)].[PharmacyMill].[DispenseHistoryMed];
GO
CREATE SYNONYM [PharmacyMill].[DispenseHistoryStatus] FOR [$(CDWWork2)].[PharmacyMill].[DispenseHistoryStatus];
GO
CREATE SYNONYM [PharmacyMill].[MedDispense] FOR [$(CDWWork2)].[PharmacyMill].[MedDispense];
GO
CREATE SYNONYM [PharmacyMill].[MedDispenseFlexMethod] FOR [$(CDWWork2)].[PharmacyMill].[MedDispenseFlexMethod];
GO
CREATE SYNONYM [PharmacyMill].[MedDispenseOrder] FOR [$(CDWWork2)].[PharmacyMill].[MedDispenseOrder];
GO
CREATE SYNONYM [PharmacyMill].[MedFlexObject] FOR [$(CDWWork2)].[PharmacyMill].[MedFlexObject];
GO
CREATE SYNONYM [PharmacyMill].[MedFormularyIdentifier] FOR [$(CDWWork2)].[PharmacyMill].[MedFormularyIdentifier];
GO
CREATE SYNONYM [PharmacyMill].[MedOrderProduct] FOR [$(CDWWork2)].[PharmacyMill].[MedOrderProduct];
GO
CREATE SYNONYM [PharmacyMill].[PharmacyOrderInfoDispense] FOR [$(CDWWork2)].[PharmacyMill].[PharmacyOrderInfoDispense];
GO
CREATE SYNONYM [PharmacyMill].[PharmacyOrderInfoInstruction] FOR [$(CDWWork2)].[PharmacyMill].[PharmacyOrderInfoInstruction];
GO
CREATE SYNONYM [PharmacyMill].[PharmacyOrderInfoPatient] FOR [$(CDWWork2)].[PharmacyMill].[PharmacyOrderInfoPatient];
GO
CREATE SYNONYM [PharmacyMill].[PharmacyRange] FOR [$(CDWWork2)].[PharmacyMill].[PharmacyRange];
GO
CREATE SYNONYM [PharmacyMill].[PrescriptionStatus] FOR [$(CDWWork2)].[PharmacyMill].[PrescriptionStatus];
GO
CREATE SYNONYM [PharmacyMill].[RxSuspendActLog] FOR [$(CDWWork2)].[PharmacyMill].[RxSuspendActLog];
GO
CREATE SYNONYM [PharmacyMill].[RxSuspendActLogDetail] FOR [$(CDWWork2)].[PharmacyMill].[RxSuspendActLogDetail];
GO
CREATE SYNONYM [ProblemMill].[Problem] FOR [$(CDWWork2)].[ProblemMill].[Problem];
GO
CREATE SYNONYM [SchedMill].[ScheduleAppointment] FOR [$(CDWWork2)].[SchedMill].[ScheduleAppointment];
GO
CREATE SYNONYM [SchedMill].[ScheduleEvent] FOR [$(CDWWork2)].[SchedMill].[ScheduleEvent];
GO
CREATE SYNONYM [SchedMill].[ScheduleEventAction] FOR [$(CDWWork2)].[SchedMill].[ScheduleEventAction];
GO
CREATE SYNONYM [SchedMill].[ScheduleEventAttachment] FOR [$(CDWWork2)].[SchedMill].[ScheduleEventAttachment];
GO
CREATE SYNONYM [SchedMill].[ScheduleEventDetail] FOR [$(CDWWork2)].[SchedMill].[ScheduleEventDetail];
GO
CREATE SYNONYM [SchedMill].[SchedulePatientEvent] FOR [$(CDWWork2)].[SchedMill].[SchedulePatientEvent];
GO
CREATE SYNONYM [SStaffMill].[SPersonStaff] FOR [$(CDWWork2)].[SStaffMill].[SPersonStaff];
GO
CREATE SYNONYM [SStaffMill].[SPersonStaffAlias] FOR [$(CDWWork2)].[SStaffMill].[SPersonStaffAlias];
GO
CREATE SYNONYM [StaffMill].[PersonStaff] FOR [$(CDWWork2)].[StaffMill].[PersonStaff];
GO
CREATE SYNONYM [StaffMill].[Referral] FOR [$(CDWWork2)].[StaffMill].[Referral];
GO
CREATE SYNONYM [StaffMill].[ReferralAction] FOR [$(CDWWork2)].[StaffMill].[ReferralAction];
GO
CREATE SYNONYM [StaffMill].[ReferralEntityRelation] FOR [$(CDWWork2)].[StaffMill].[ReferralEntityRelation];
GO
CREATE SYNONYM [SurgMill].[SurgicalCase] FOR [$(CDWWork2)].[SurgMill].[SurgicalCase];
GO
CREATE SYNONYM [SurgMill].[SurgProcedure] FOR [$(CDWWork2)].[SurgMill].[SurgProcedure];
GO
CREATE SYNONYM [SVeteranMill].[EncounterHealthPlan] FOR [$(CDWWork2)].[SVeteranMill].[EncounterHealthPlan];
GO
CREATE SYNONYM [SVeteranMill].[SPerson] FOR [$(CDWWork2)].[SVeteranMill].[SPerson];
GO
CREATE SYNONYM [SVeteranMill].[SPersonAddress] FOR [$(CDWWork2)].[SVeteranMill].[SPersonAddress];
GO
CREATE SYNONYM [SVeteranMill].[SPersonAlias] FOR [$(CDWWork2)].[SVeteranMill].[SPersonAlias];
GO
CREATE SYNONYM [SVeteranMill].[SPersonPhone] FOR [$(CDWWork2)].[SVeteranMill].[SPersonPhone];
GO
CREATE SYNONYM [SVeteranMill].[SPersonRelation] FOR [$(CDWWork2)].[SVeteranMill].[SPersonRelation];
GO
CREATE SYNONYM [VeteranMill].[Person] FOR [$(CDWWork2)].[VeteranMill].[Person];
GO
CREATE SYNONYM [VeteranMill].[PersonAlias] FOR [$(CDWWork2)].[VeteranMill].[PersonAlias];
GO
CREATE SYNONYM [VeteranMill].[PersonHistoryInfo] FOR [$(CDWWork2)].[VeteranMill].[PersonHistoryInfo];
GO
CREATE SYNONYM [VeteranMill].[PersonInformation] FOR [$(CDWWork2)].[VeteranMill].[PersonInformation];
GO
CREATE SYNONYM [VeteranMill].[PersonTransaction] FOR [$(CDWWork2)].[VeteranMill].[PersonTransaction];
GO
CREATE SYNONYM [VeteranMill].[PersonVeteran] FOR [$(CDWWork2)].[VeteranMill].[PersonVeteran];
GO
