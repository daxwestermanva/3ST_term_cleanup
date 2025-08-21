/*
Use this file to manage synonyms that refer to objects in CDWWork

NAMING CONVENTION: Same schema and name as original object.

NOTE: Add new synonyms in the correct alphabetical order.

MODIFICATIONS:
	2022-05-06	RAS	Created file with all synonyms. Pointed Mill objects to OMHSP_PERC_Core, then evaluated what broke in dependencies.
					Commented out items that need to use SPV2 or SPV -- these will persist as views until moved to Core.
	2022-06-07	RAS	Pointed synonyms to Core except where build failed (objects used in views could not be changed to point to Core).
	2022-06-16	JEB	Added new synonym to Core for [NDimMill].[AppointmentOption] per request from Craig
	2022-06-22	JEB Added new Synonym to Core for [NDimMill].[OrganizationTypeRelation], per request from Steve A
	2022-07-07	RAS	Replaced remaining view objects with synonyms to Core (SPatient.SPatient, EncMill.Encounter, 
					NDimMill.CatalogItemRelationship, NDimMill.CodeValue, NDimMill.CodeValueGroup, NDimMill.CodeValueSet)
	2022-08-04	JEB Making this the 'master' file and copying it over to all sister systems. Also alphabetized. Centalization to one file will be done at a later dat (if it's possible, that is)
	2022-08-18	RAS	Branched to create separate files for CDWWork and CDWWork2
	2023-04-18  AER Added Micro synonyms 
	2023-09-12  SG Added Dim.ActivityType 
	2024-01-30  GC Added Appt.Appointment_Recent and Outpat.visit_Recent 
	2024-09-25  GC Added [RPCMM].[CurrentProviderTeamMembership]
	2024-11-12  TG Added [RxOut].[eRxHoldingQueue]
	2025-03-31	CJK added synonyms to [BaseCamp] schema objects
*/

CREATE SYNONYM [ADR].[ADREnrollHistory] FOR [$(CDWWork)].[ADR].[ADREnrollHistory];
GO
CREATE SYNONYM [Appt].[Appointment] FOR [$(CDWWork)].[Appt].[Appointment];
GO
CREATE SYNONYM [Appt].[Appointment_Recent] FOR [$(CDWWork)].[Appt].[Appointment_Recent];
GO
CREATE SYNONYM [BaseCamp].[Customer] FOR [$(CDWWork)].[BaseCamp].[Customer]
GO
CREATE SYNONYM [BaseCamp].[CustomerAuthorization] FOR [$(CDWWork)].[BaseCamp].[CustomerAuthorization]
GO
CREATE SYNONYM [BaseCamp].[Task] FOR [$(CDWWork)].[BaseCamp].[Task]
GO
CREATE SYNONYM [BaseCamp].[WorkgroupClearance] FOR [$(CDWWork)].[BaseCamp].[WorkgroupClearance]
GO
CREATE SYNONYM [BaseCamp].[WorkgroupMembership] FOR [$(CDWWork)].[BaseCamp].[WorkgroupMembership]
GO
CREATE SYNONYM [BaseCamp].[WorkgroupPermission] FOR [$(CDWWork)].[BaseCamp].[WorkgroupPermission]
GO
CREATE SYNONYM [BCMA].[BCMADispensedDrug] FOR [$(CDWWork)].[BCMA].[BCMADispensedDrug];
GO
CREATE SYNONYM [BCMA].[BCMAMedicationLog] FOR [$(CDWWork)].[BCMA].[BCMAMedicationLog];
GO
CREATE SYNONYM [Chem].[LabChem] FOR [$(CDWWork)].[Chem].[LabChem];
GO
CREATE SYNONYM [Con].[Consult] FOR [$(CDWWork)].[Con].[Consult];
GO
CREATE SYNONYM [Con].[ConsultActivity] FOR [$(CDWWork)].[Con].[ConsultActivity];
GO
CREATE SYNONYM [Con].[ConsultFactor] FOR [$(CDWWork)].[Con].[ConsultFactor];
GO
CREATE SYNONYM [CPRSOrder].[CPRSOrder] FOR [$(CDWWork)].[CPRSOrder].[CPRSOrder];
GO
CREATE SYNONYM [CPRSOrder].[OrderedItem] FOR [$(CDWWork)].[CPRSOrder].[OrderedItem];
GO
CREATE SYNONYM [Dim].[AccessionArea] FOR [$(CDWWork)].[Dim].[AccessionArea];
GO
CREATE SYNONYM [Dim].[AccessioningInstitution] FOR [$(CDWWork)].[Dim].[AccessioningInstitution];
GO
CREATE SYNONYM [Dim].[AppointmentStatus] FOR [$(CDWWork)].[Dim].[AppointmentStatus];
GO
CREATE SYNONYM [Dim].[AppointmentType] FOR [$(CDWWork)].[Dim].[AppointmentType];
GO
CREATE SYNONYM [Dim].[BranchOfService] FOR [$(CDWWork)].[Dim].[BranchOfService];
GO
CREATE SYNONYM [Dim].[CancellationReason] FOR [$(CDWWork)].[Dim].[CancellationReason];
GO
CREATE SYNONYM [Dim].[CPRSTabKey] FOR [$(CDWWork)].[Dim].[CPRSTabKey];
GO
CREATE SYNONYM [Dim].[CollectionSample] FOR [$(CDWWork)].[Dim].[CollectionSample];
GO
CREATE SYNONYM [Dim].[Country] FOR [$(CDWWork)].[Dim].[Country];
GO
CREATE SYNONYM [Dim].[CPT] FOR [$(CDWWork)].[Dim].[CPT];
GO
CREATE SYNONYM [Dim].[CPTModifier] FOR [$(CDWWork)].[Dim].[CPTModifier];
GO
CREATE SYNONYM [Dim].[Date] FOR [$(CDWWork)].[Dim].[Date];
GO
CREATE SYNONYM [Dim].[DispenseUnit] FOR [$(CDWWork)].[Dim].[DispenseUnit];
GO
CREATE SYNONYM [Dim].[DisplayGroup] FOR [$(CDWWork)].[Dim].[DisplayGroup];
GO
CREATE SYNONYM [Dim].[Division] FOR [$(CDWWork)].[Dim].[Division];
GO
CREATE SYNONYM [Dim].[DosageForm] FOR [$(CDWWork)].[Dim].[DosageForm];
GO
CREATE SYNONYM [Dim].[DrugClass] FOR [$(CDWWork)].[Dim].[DrugClass];
GO
CREATE SYNONYM [Dim].[DrugNameWithoutDose] FOR [$(CDWWork)].[Dim].[DrugNameWithoutDose];
GO
CREATE SYNONYM [Dim].[DSSLocation] FOR [$(CDWWork)].[Dim].[DSSLocation];
GO
CREATE SYNONYM [Dim].[DSSLocationStopCode] FOR [$(CDWWork)].[Dim].[DSSLocationStopCode];
GO
CREATE SYNONYM [Dim].[Eligibility] FOR [$(CDWWork)].[Dim].[Eligibility];
GO
CREATE SYNONYM [Dim].[EnrollmentStatus] FOR [$(CDWWork)].[Dim].[EnrollmentStatus];
GO
CREATE SYNONYM [Dim].[HealthFactorType] FOR [$(CDWWork)].[Dim].[HealthFactorType];
GO
CREATE SYNONYM [Dim].[IBActionType] FOR [$(CDWWork)].[Dim].[IBActionType];
GO
CREATE SYNONYM [Dim].[IBChargeRemoveReason] FOR [$(CDWWork)].[Dim].[IBChargeRemoveReason];
GO
CREATE SYNONYM [Dim].[ICD] FOR [$(CDWWork)].[Dim].[ICD];
GO
CREATE SYNONYM [Dim].[ICD10] FOR [$(CDWWork)].[Dim].[ICD10];
GO
CREATE SYNONYM [Dim].[ICD10DescriptionVersion] FOR [$(CDWWork)].[Dim].[ICD10DescriptionVersion];
GO
CREATE SYNONYM [Dim].[ICD10Procedure] FOR [$(CDWWork)].[Dim].[ICD10Procedure];
GO
CREATE SYNONYM [Dim].[ICD10ProcedureDescriptionVersion] FOR [$(CDWWork)].[Dim].[ICD10ProcedureDescriptionVersion];
GO
CREATE SYNONYM [Dim].[ICD9] FOR [$(CDWWork)].[Dim].[ICD9];
GO
CREATE SYNONYM [Dim].[ICD9DescriptionVersion] FOR [$(CDWWork)].[Dim].[ICD9DescriptionVersion];
GO
CREATE SYNONYM [Dim].[ICD9Procedure] FOR [$(CDWWork)].[Dim].[ICD9Procedure];
GO
CREATE SYNONYM [Dim].[ICD9ProcedureDescriptionVersion] FOR [$(CDWWork)].[Dim].[ICD9ProcedureDescriptionVersion];
GO
CREATE SYNONYM [Dim].[ImmunizationName] FOR [$(CDWWork)].[Dim].[ImmunizationName];
GO
CREATE SYNONYM [Dim].[Institution] FOR [$(CDWWork)].[Dim].[Institution];
GO
CREATE SYNONYM [Dim].[LabChemTest] FOR [$(CDWWork)].[Dim].[LabChemTest];
GO
CREATE SYNONYM [Dim].[LabChemTestPanelList] FOR [$(CDWWork)].[Dim].[LabChemTestPanelList];
GO
CREATE SYNONYM [Dim].[LabChemTestSpecimen] FOR [$(CDWWork)].[Dim].[LabChemTestSpecimen];
GO
CREATE SYNONYM [Dim].[LocalDrug] FOR [$(CDWWork)].[Dim].[LocalDrug];
GO
CREATE SYNONYM [Dim].[LocalPatientRecordFlag] FOR [$(CDWWork)].[Dim].[LocalPatientRecordFlag];
GO
CREATE SYNONYM [Dim].[Location] FOR [$(CDWWork)].[Dim].[Location];
GO
CREATE SYNONYM [Dim].[LocationProvider] FOR [$(CDWWork)].[Dim].[LocationProvider];
GO
CREATE SYNONYM [Dim].[LOINC] FOR [$(CDWWork)].[Dim].[LOINC];
GO
CREATE SYNONYM [Dim].[MaritalStatus] FOR [$(CDWWork)].[Dim].[MaritalStatus];
GO
CREATE SYNONYM [Dim].[NationalDrug] FOR [$(CDWWork)].[Dim].[NationalDrug];
GO
CREATE SYNONYM [Dim].[NationalPatientRecordFlag] FOR [$(CDWWork)].[Dim].[NationalPatientRecordFlag];
GO
CREATE SYNONYM [Dim].[NationalVALabCode] FOR [$(CDWWork)].[Dim].[NationalVALabCode];
GO
CREATE SYNONYM [Dim].[OrderableItem] FOR [$(CDWWork)].[Dim].[OrderableItem];
GO
CREATE SYNONYM [Dim].[OrderStatus] FOR [$(CDWWork)].[Dim].[OrderStatus];
GO
CREATE SYNONYM [Dim].[Organism] FOR [$(CDWWork)].[Dim].[Organism];
GO
CREATE SYNONYM [Dim].[PatientRecordFlagType] FOR [$(CDWWork)].[Dim].[PatientRecordFlagType];
GO
CREATE SYNONYM [Dim].[PharmacyOrderableItem] FOR [$(CDWWork)].[Dim].[PharmacyOrderableItem];
GO
CREATE SYNONYM [Dim].[PlaceOfDisposition] FOR [$(CDWWork)].[Dim].[PlaceOfDisposition];
GO
CREATE SYNONYM [Dim].[PronounType] FOR [$(CDWWork)].[Dim].[PronounType];
GO
CREATE SYNONYM [Dim].[ProviderType] FOR [$(CDWWork)].[Dim].[ProviderType];
GO
CREATE SYNONYM [Dim].[RequestService] FOR [$(CDWWork)].[Dim].[RequestService];
GO
CREATE SYNONYM [Dim].[SexualOrientationType] FOR [$(CDWWork)].[Dim].[SexualOrientationType];
GO
CREATE SYNONYM [Dim].[Specialty] FOR [$(CDWWork)].[Dim].[Specialty];
GO
CREATE SYNONYM [Dim].[Sta3n] FOR [$(CDWWork)].[Dim].[Sta3n];
GO
CREATE SYNONYM [Dim].[State] FOR [$(CDWWork)].[Dim].[State];
GO
CREATE SYNONYM [Dim].[StateCounty] FOR [$(CDWWork)].[Dim].[StateCounty];
GO
CREATE SYNONYM [Dim].[StopCode] FOR [$(CDWWork)].[Dim].[StopCode];
GO
CREATE SYNONYM [Dim].[Survey] FOR [$(CDWWork)].[Dim].[Survey];
GO
CREATE SYNONYM [Dim].[SurveyChoice] FOR [$(CDWWork)].[Dim].[SurveyChoice];
GO
CREATE SYNONYM [Dim].[SurveyContent] FOR [$(CDWWork)].[Dim].[SurveyContent];
GO
CREATE SYNONYM [Dim].[SurveyQuestion] FOR [$(CDWWork)].[Dim].[SurveyQuestion];
GO
CREATE SYNONYM [Dim].[Team] FOR [$(CDWWork)].[Dim].[Team];
GO
CREATE SYNONYM [Dim].[Time] FOR [$(CDWWork)].[Dim].[Time];
GO
CREATE SYNONYM [Dim].[TIUDocumentDefinition] FOR [$(CDWWork)].[Dim].[TIUDocumentDefinition];
GO
CREATE SYNONYM [Dim].[TIUDocumentType] FOR [$(CDWWork)].[Dim].[TIUDocumentType];
GO
CREATE SYNONYM [Dim].[TIUStandardTitle] FOR [$(CDWWork)].[Dim].[TIUStandardTitle];
GO
CREATE SYNONYM [Dim].[TIUStatus] FOR [$(CDWWork)].[Dim].[TIUStatus];
GO
CREATE SYNONYM [Dim].[TIUSubjectMatterDomain] FOR [$(CDWWork)].[Dim].[TIUSubjectMatterDomain];
GO
CREATE SYNONYM [Dim].[Topography] FOR [$(CDWWork)].[Dim].[Topography];
GO
CREATE SYNONYM [Dim].[TreatingSpecialty] FOR [$(CDWWork)].[Dim].[TreatingSpecialty];
GO
CREATE SYNONYM [Dim].[VistaPackage] FOR [$(CDWWork)].[Dim].[VistaPackage];
GO
CREATE SYNONYM [Dim].[VistASite] FOR [$(CDWWork)].[Dim].[VistASite];
GO
CREATE SYNONYM [Dim].[VitalType] FOR [$(CDWWork)].[Dim].[VitalType];
GO
CREATE SYNONYM [Dim].[WardLocation] FOR [$(CDWWork)].[Dim].[WardLocation];
GO
CREATE SYNONYM [Fee].[FeeInitialTreatment] FOR [$(CDWWork)].[Fee].[FeeInitialTreatment];
GO
CREATE SYNONYM [Fee].[FeeInpatInvoice] FOR [$(CDWWork)].[Fee].[FeeInpatInvoice];
GO
CREATE SYNONYM [Fee].[FeeInpatInvoiceICDDiagnosis] FOR [$(CDWWork)].[Fee].[FeeInpatInvoiceICDDiagnosis];
GO
CREATE SYNONYM [Fee].[FeeServiceProvided] FOR [$(CDWWork)].[Fee].[FeeServiceProvided];
GO
CREATE SYNONYM [HF].[HealthFactor] FOR [$(CDWWork)].[HF].[HealthFactor];
GO
CREATE SYNONYM [IB].[AccountsReceivable] FOR [$(CDWWork)].[IB].[AccountsReceivable];
GO
CREATE SYNONYM [IB].[ARTransaction] FOR [$(CDWWork)].[IB].[ARTransaction];
GO
CREATE SYNONYM [IB].[IBAction] FOR [$(CDWWork)].[IB].[IBAction];
GO
CREATE SYNONYM [Immun].[Immunization] FOR [$(CDWWork)].[Immun].[Immunization];
GO
CREATE SYNONYM [Inpat].[Census] FOR [$(CDWWork)].[Inpat].[Census];
GO
CREATE SYNONYM [Inpat].[Census501] FOR [$(CDWWork)].[Inpat].[Census501];
GO
CREATE SYNONYM [Inpat].[CensusDiagnosis] FOR [$(CDWWork)].[Inpat].[CensusDiagnosis];
GO
CREATE SYNONYM [Inpat].[Inpatient] FOR [$(CDWWork)].[Inpat].[Inpatient];
GO
CREATE SYNONYM [Inpat].[InpatientCPTProcedure] FOR [$(CDWWork)].[Inpat].[InpatientCPTProcedure];
GO
CREATE SYNONYM [Inpat].[InpatientDiagnosis] FOR [$(CDWWork)].[Inpat].[InpatientDiagnosis];
GO
CREATE SYNONYM [Inpat].[InpatientDischargeDiagnosis] FOR [$(CDWWork)].[Inpat].[InpatientDischargeDiagnosis];
GO
CREATE SYNONYM [Inpat].[InpatientFeeBasis] FOR [$(CDWWork)].[Inpat].[InpatientFeeBasis];
GO
CREATE SYNONYM [Inpat].[InpatientFeeDiagnosis] FOR [$(CDWWork)].[Inpat].[InpatientFeeDiagnosis];
GO
CREATE SYNONYM [Inpat].[InpatientICDProcedure] FOR [$(CDWWork)].[Inpat].[InpatientICDProcedure];
GO
CREATE SYNONYM [Inpat].[PatientTransfer] FOR [$(CDWWork)].[Inpat].[PatientTransfer];
GO
CREATE SYNONYM [Inpat].[PatientTransferDiagnosis] FOR [$(CDWWork)].[Inpat].[PatientTransferDiagnosis];
GO
CREATE SYNONYM [Inpat].[SpecialtyTransfer] FOR [$(CDWWork)].[Inpat].[SpecialtyTransfer];
GO
CREATE SYNONYM [Inpat].[SpecialtyTransferDiagnosis] FOR [$(CDWWork)].[Inpat].[SpecialtyTransferDiagnosis];
GO
CREATE SYNONYM [LCustomer].[AllAuthorization] FOR [$(CDWWork)].[LCustomer].[AllAuthorization];
GO
CREATE SYNONYM [LCustomer].[AllPermissions] FOR [$(CDWWork)].[LCustomer].[AllPermissions];
GO
CREATE SYNONYM [LCustomer].[LCustomer] FOR [$(CDWWork)].[LCustomer].[LCustomer];
GO
CREATE SYNONYM [LCustomer].[MyAuthorization] FOR [$(CDWWork)].[LCustomer].[MyAuthorization];
GO
CREATE SYNONYM [Meta].[DWView] FOR [$(CDWWork)].[Meta].[DWView];
GO
CREATE SYNONYM [Meta].[DWViewField] FOR [$(CDWWork)].[Meta].[DWViewField];
GO
CREATE SYNONYM [MH].[SurveyAdministration] FOR [$(CDWWork)].[MH].[SurveyAdministration];
GO
CREATE SYNONYM [MH].[SurveyAnswer] FOR [$(CDWWork)].[MH].[SurveyAnswer];
GO
CREATE SYNONYM [MH].[SurveyResult] FOR [$(CDWWork)].[MH].[SurveyResult];
GO
CREATE SYNONYM [Micro].[AntibioticSensitivity] FOR [$(CDWWork)].[Micro].[AntibioticSensitivity]; 
GO
CREATE SYNONYM [Micro].[Microbiology] FOR [$(CDWWork)].[Micro].[Microbiology];
GO
CREATE SYNONYM [NDim].[ADREnrollStatus] FOR [$(CDWWork)].[NDim].[ADREnrollStatus];
GO
CREATE SYNONYM [NDim].[ADRPriorityGroup] FOR [$(CDWWork)].[NDim].[ADRPriorityGroup];
GO
CREATE SYNONYM [NDim].[ADRPrioritySubGroup] FOR [$(CDWWork)].[NDim].[ADRPrioritySubGroup];
GO
CREATE SYNONYM [NDim].[MVICountryCode] FOR [$(CDWWork)].[NDim].[MVICountryCode];
GO
CREATE SYNONYM [NDim].[MVIMaritalStatus] FOR [$(CDWWork)].[NDim].[MVIMaritalStatus];
GO
CREATE SYNONYM [NDim].[MVIPronounType] FOR [$(CDWWork)].[NDim].[MVIPronounType];
GO
CREATE SYNONYM [NDim].[MVIState] FOR [$(CDWWork)].[NDim].[MVIState];
GO
CREATE SYNONYM [NDim].[MVISexualOrientationType] FOR [$(CDWWork)].[NDim].[MVISexualOrientationType];
GO
CREATE SYNONYM [NDim].[PyramidUSZipCode] FOR [$(CDWWork)].[NDim].[PyramidUSZipCode];
GO
CREATE SYNONYM [NDim].[RPCMMStaffRole] FOR [$(CDWWork)].[NDim].[RPCMMStaffRole];
GO
CREATE SYNONYM [NDim].[RPCMMTeam] FOR [$(CDWWork)].[NDim].[RPCMMTeam];
GO
CREATE SYNONYM [NDim].[RPCMMTeamCareType] FOR [$(CDWWork)].[NDim].[RPCMMTeamCareType];
GO
CREATE SYNONYM [NDim].[RPCMMTeamFocus] FOR [$(CDWWork)].[NDim].[RPCMMTeamFocus];
GO
CREATE SYNONYM [NDim].[RPCMMTeamPosition] FOR [$(CDWWork)].[NDim].[RPCMMTeamPosition];
GO
CREATE SYNONYM [NDim].[RPCMMTeamRole] FOR [$(CDWWork)].[NDim].[RPCMMTeamRole];
GO
CREATE SYNONYM [NonVAMed].[NonVAMed] FOR [$(CDWWork)].[NonVAMed].[NonVAMed];
GO
CREATE SYNONYM [Outpat].[ProblemList] FOR [$(CDWWork)].[Outpat].[ProblemList];
GO
CREATE SYNONYM [Outpat].[VDiagnosis] FOR [$(CDWWork)].[Outpat].[VDiagnosis];
GO
CREATE SYNONYM [Outpat].[Visit] FOR [$(CDWWork)].[Outpat].[Visit];
GO
CREATE SYNONYM [Outpat].[Visit_Recent] FOR [$(CDWWork)].[Outpat].[Visit_Recent];
GO
CREATE SYNONYM [Outpat].[VProcedure] FOR [$(CDWWork)].[Outpat].[VProcedure];
GO
CREATE SYNONYM [Outpat].[VProcedureCPTModifier] FOR [$(CDWWork)].[Outpat].[VProcedureCPTModifier];
GO
CREATE SYNONYM [Outpat].[VProvider] FOR [$(CDWWork)].[Outpat].[VProvider];
GO
CREATE SYNONYM [Patient].[CompActPatient] FOR [$(CDWWork)].[Patient].[CompActPatient];
GO
CREATE SYNONYM [Patient].[CompActPatientCare] FOR [$(CDWWork)].[Patient].[CompActPatientCare];
GO
CREATE SYNONYM [Patient].[CompActPatientCareInpatient] FOR [$(CDWWork)].[Patient].[CompActPatientCareInpatient];
GO
CREATE SYNONYM [Patient].[CompActPatientCareOutpatient] FOR [$(CDWWork)].[Patient].[CompActPatientCareOutpatient];
GO
CREATE SYNONYM [Patient].[Enrollment] FOR [$(CDWWork)].[Patient].[Enrollment];
GO
CREATE SYNONYM [Patient].[Patient] FOR [$(CDWWork)].[Patient].[Patient];
GO
CREATE SYNONYM [Patient].[PatientICN] FOR [$(CDWWork)].[Patient].[PatientICN];
GO
CREATE SYNONYM [Patient].[PreferredPronoun] FOR [$(CDWWork)].[Patient].[PreferredPronoun];
GO
CREATE SYNONYM [Patient].[SexualOrientation] FOR [$(CDWWork)].[Patient].[SexualOrientation];
GO
CREATE SYNONYM [PatSub].[MilitarySexualTrauma] FOR [$(CDWWork)].[PatSub].[MilitarySexualTrauma];
GO
CREATE SYNONYM [PatSub].[OEFOIFService] FOR [$(CDWWork)].[PatSub].[OEFOIFService];
GO
CREATE SYNONYM [PatSub].[PatientRace] FOR [$(CDWWork)].[PatSub].[PatientRace];
GO
CREATE SYNONYM [PatSub].[SecondaryEligibility] FOR [$(CDWWork)].[PatSub].[SecondaryEligibility];
GO
CREATE SYNONYM [RPCMM].[CurrentPatientProviderRelationship] FOR [$(CDWWork)].[RPCMM].[CurrentPatientProviderRelationship];
GO
CREATE SYNONYM [RPCMM].[CurrentPatientTeamMembership] FOR [$(CDWWork)].[RPCMM].[CurrentPatientTeamMembership];
GO
CREATE SYNONYM [RPCMM].[CurrentProviderTeamMembership] FOR [$(CDWWork)].[RPCMM].[CurrentProviderTeamMembership];
GO
CREATE SYNONYM [RPCMM].[CurrentRPCMMProviderFTEE] FOR [$(CDWWork)].[RPCMM].[CurrentRPCMMProviderFTEE];
GO
CREATE SYNONYM [RxOut].[eRxHoldingQueue] FOR [$(CDWWork)].[RxOut].[eRxHoldingQueue];
GO
CREATE SYNONYM [RxOut].[RxOutpat] FOR [$(CDWWork)].[RxOut].[RxOutpat];
GO
CREATE SYNONYM [RxOut].[RxOutpatFill] FOR [$(CDWWork)].[RxOut].[RxOutpatFill];
GO
CREATE SYNONYM [RxOut].[RxOutpatMedInstructions] FOR [$(CDWWork)].[RxOut].[RxOutpatMedInstructions];
GO
CREATE SYNONYM [RxOut].[RxOutpatSig] FOR [$(CDWWork)].[RxOut].[RxOutpatSig];
GO
CREATE SYNONYM [SPatient].[MilitaryServiceEpisode] FOR [$(CDWWork)].[SPatient].[MilitaryServiceEpisode];
GO
CREATE SYNONYM [SPatient].[PatientRecordFlagAssignment] FOR [$(CDWWork)].[SPatient].[PatientRecordFlagAssignment];
GO
CREATE SYNONYM [SPatient].[PatientRecordFlagHistory] FOR [$(CDWWork)].[SPatient].[PatientRecordFlagHistory];
GO
CREATE SYNONYM [SPatient].[SConsultActivityComment_Recent] FOR [$(CDWWork)].[SPatient].[SConsultActivityComment_Recent];
GO
CREATE SYNONYM [SPatient].[SConsultReason] FOR [$(CDWWork)].[SPatient].[SConsultReason];
GO
CREATE SYNONYM [SPatient].[SPatient] FOR [$(CDWWork)].[SPatient].[SPatient];
GO
CREATE SYNONYM [SPatient].[SPatientAddress] FOR [$(CDWWork)].[SPatient].[SPatientAddress];
GO
CREATE SYNONYM [SPatient].[SPatientDisability] FOR [$(CDWWork)].[SPatient].[SPatientDisability];
GO
CREATE SYNONYM [SPatient].[SPatientGISAddress] FOR [$(CDWWork)].[SPatient].[SPatientGISAddress];
GO
CREATE SYNONYM [SPatient].[SPatientPhone] FOR [$(CDWWork)].[SPatient].[SPatientPhone];
GO
CREATE SYNONYM [SStaff].[SStaff] FOR [$(CDWWork)].[SStaff].[SStaff];
GO
CREATE SYNONYM [Staff].[StaffChangeMod] FOR [$(CDWWork)].[Staff].[StaffChangeMod];
GO
CREATE SYNONYM [StaffSub].[CPRSTabPermission] FOR [$(CDWWork)].[StaffSub].[CPRSTabPermission];
GO
CREATE SYNONYM [SVeteran].[SMVIPerson] FOR [$(CDWWork)].[SVeteran].[SMVIPerson];
GO
CREATE SYNONYM [SVeteran].[SMVIPersonAlias] FOR [$(CDWWork)].[SVeteran].[SMVIPersonAlias];
GO
CREATE SYNONYM [SVeteran].[SMVIPersonSiteAssociation] FOR [$(CDWWork)].[SVeteran].[SMVIPersonSiteAssociation];
GO
CREATE SYNONYM [TIU].[TIUDocument] FOR [$(CDWWork)].[TIU].[TIUDocument];
GO
CREATE SYNONYM [Veteran].[ADRPerson] FOR [$(CDWWork)].[Veteran].[ADRPerson];
GO
CREATE SYNONYM [Veteran].[MVIPerson] FOR [$(CDWWork)].[Veteran].[MVIPerson];
GO
CREATE SYNONYM [Veteran].[MVIPersonPreferredPronoun] FOR [$(CDWWork)].[Veteran].[MVIPersonPreferredPronoun];
GO
CREATE SYNONYM [Veteran].[MVIPersonSexualOrientation] FOR [$(CDWWork)].[Veteran].[MVIPersonSexualOrientation];
GO
CREATE SYNONYM [Vital].[VitalSign] FOR [$(CDWWork)].[Vital].[VitalSign];
GO
CREATE SYNONYM [Dim].[ActivityType] FOR [$(CDWWork)].[Dim].[ActivityType];
GO
