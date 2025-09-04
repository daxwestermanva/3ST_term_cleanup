
CREATE VIEW [App].[vwCDW_Outpat_Workload]
AS  
SELECT 
--------------------------------------------------------------------------------------------------------------------------------------------
--2021/08/06	JB Enclave Work - Converted new view with vw naming convention, also using A01 naming convention from source objects
--2021/09/01	JB Enclave Work - Converted join for MVIPersonSID to be an INNER JOIN, so that SPs using this view will run faster.
--								- Note, INNER JOIN means that any non matching PatientSID values will not be included in this view.
--------------------------------------------------------------------------------------------------------------------------------------------
  V.VisitSID as VisitSID
  --, V.VisitIEN as VisitIEN
  , V.Sta3n as Sta3n
  , V.VisitDateTime as VisitDateTime
  --, V.VisitVistaErrorDate as VisitVistaErrorDate
  --, V.VisitDateTimeTransformSID as VisitDateTimeTransformSID
  , V.EncounterDateTime as EncounterDateTime
  --, V.EncounterVistaErrorDate as EncounterVistaErrorDate
  --, V.EncounterDateTimeTransformSID as EncounterDateTimeTransformSID
  --, V.CreatedByStaffSID as CreatedByStaffSID
  --, V.EncounterCreatedByStaffSID as EncounterCreatedByStaffSID
  --, V.VisitCreatedDateTime as VisitCreatedDateTime
  --, V.VisitCreatedVistaErrorDate as VisitCreatedVistaErrorDate
  --, V.VisitCreatedDateTimeTransformSID as VisitCreatedDateTimeTransformSID
  --, V.EncounterCreatedDateTime as EncounterCreatedDateTime
  --, V.EncounterCreatedVistaErrorDate as EncounterCreatedVistaErrorDate
  --, V.EncounterCreatedDateTimeTransformSID as EncounterCreatedDateTimeTransformSID
  , V.EncounterLastEditedByStaffSID as EncounterLastEditedByStaffSID
  , V.LastModifiedDateTime as LastModifiedDateTime
  --, V.LastModifiedVistaErrorDate as LastModifiedVistaErrorDate
  --, V.LastModifiedDateTimeTransformSID as LastModifiedDateTimeTransformSID
  --, V.EncounterLastEditedDateTime as EncounterLastEditedDateTime
  --, V.EncounterLastEditedVistaErrorDate as EncounterLastEditedVistaErrorDate
  --, V.EncounterLastEditedDateTimeTransformSID as EncounterLastEditedDateTimeTransformSID
  --, V.CheckOutDateTime as CheckOutDateTime
  --, V.CheckOutVistaErrorDate as CheckOutVistaErrorDate
  --, V.CheckOutDateTimeTransformSID as CheckOutDateTimeTransformSID
  --, V.COProcessCompleteDateTime as COProcessCompleteDateTime
  --, V.COProcessCompleteVistaErrorDate as COProcessCompleteVistaErrorDate
  --, V.COProcessCompleteDateTimeTransformSID as COProcessCompleteDateTimeTransformSID
  --, V.VisitIdentifier as VisitIdentifier
  --, V.UniqueVisitNumber as UniqueVisitNumber
  , V.InstitutionSID as InstitutionSID
  , L.DivisionSID as DivisionSID
  , V.DivisionSID as EncounterDivisionSID
  , V.LocationSID as LocationSID
  --, V.NoncountClinicFlag as NoncountClinicFlag
  , V.PrimaryStopCodeSID as PrimaryStopCodeSID
  , V.SecondaryStopCodeSID as SecondaryStopCodeSID
  --, V.OriginatingProcessType as OriginatingProcessType
  --, V.ExtendedReference as ExtendedReference
  --, V.ServiceCategory as ServiceCategory
  --, V.EncounterType as EncounterType
  --, V.PatientStatusInOut as PatientStatusInOut
  --, V.AppointmentTypeSID as AppointmentTypeSID
  , V.AppointmentStatusSID as AppointmentStatusSID
  --, V.EncounterComputerGeneratedFlag as EncounterComputerGeneratedFlag
  --, V.UnresolvedAppointmentTypeReason as UnresolvedAppointmentTypeReason
  --, V.VisitDependentEntryCount as VisitDependentEntryCount
  --, V.ParentVisitSID as ParentVisitSID
  --, V.NonVAVisitType as NonVAVisitType
  --, V.ProviderCount as ProviderCount
  --, V.DiagnosisCount as DiagnosisCount
  --, V.ProcedureCount as ProcedureCount
  , V.PatientSID as PatientSID
  --, V.PatientVeteranFlag as PatientVeteranFlag
  --, V.PatientPeriodOfService as PatientPeriodOfService
  --, V.PatientMeansTestStatus as PatientMeansTestStatus
  --, V.PatientDerivedMeansTestCategory as PatientDerivedMeansTestCategory
  --, V.EligibilitySID as EligibilitySID
  --, V.PatientMaritalStatus as PatientMaritalStatus
  --, V.PatientReligionCode as PatientReligionCode
  --, V.PatientReligion as PatientReligion
  --, V.PatientIncome as PatientIncome
  --, V.PatientNumberOfDependents as PatientNumberOfDependents
  --, V.PatientFIPS as PatientFIPS
  , V.County as County
  --, V.PatientZIP as PatientZIP
  --, V.PatientInsuranceCoverageFlag as PatientInsuranceCoverageFlag
  --, V.PatientInsuranceType as PatientInsuranceType
  --, V.PatientPercentServiceConnect as PatientPercentServiceConnect
  , V.ServiceConnectedFlag as ServiceConnectedFlag
  --, V.PatientCombatIndicatedFlag as PatientCombatIndicatedFlag
  --, V.PatientCombatEndDate as PatientCombatEndDate
  --, V.PatientCombatEndVistaErrorDate as PatientCombatEndVistaErrorDate
  --, V.PatientCombatEndDateTransformSID as PatientCombatEndDateTransformSID
  --, V.CombatFlag as CombatFlag
  --, V.PatientPOWFlag as PatientPOWFlag
  --, V.PatientPOWLocation as PatientPOWLocation
  --, V.PatientVietnamServiceFlag as PatientVietnamServiceFlag
  --, V.PatientAgentOrangeFlag as PatientAgentOrangeFlag
  --, V.PatientAgentOrangeLocationCode as PatientAgentOrangeLocationCode
  --, V.AgentOrangeFlag as AgentOrangeFlag
  --, V.PatientIonizingRadiationCode as PatientIonizingRadiationCode
  --, V.IonizingRadiationFlag as IonizingRadiationFlag
  --, V.PatientNoseThroatRadiumExposureFlag as PatientNoseThroatRadiumExposureFlag
  --, V.HeadNeckCancerFlag as HeadNeckCancerFlag
  --, V.PatientSouthwestAsiaCondition as PatientSouthwestAsiaCondition
  --, V.SWAsiaConditionsFlag as SWAsiaConditionsFlag
  --, V.PatientMilitarySexualTraumaIndicator as PatientMilitarySexualTraumaIndicator
  --, V.MilitarySexualTraumaFlag as MilitarySexualTraumaFlag
  --, V.PatientShipboardHazardDefenseFlag as PatientShipboardHazardDefenseFlag
  --, V.ShipboardHazardDefenseFlag as ShipboardHazardDefenseFlag
  --, V.CreateRecordMenuOptionSID as CreateRecordMenuOptionSID
  --, V.ProtocolSID as ProtocolSID
  --, V.VistaPackageSID as VistaPackageSID
  --, V.PCEDataSourceSID as PCEDataSourceSID
	, mvi.MVIPersonSID AS MVIPersonSID
FROM [Outpat].[Visit] V WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON V.PatientSID = mvi.PatientPersonSID 
LEFT OUTER JOIN [Dim].[Location] L WITH (NOLOCK)
  on V.LocationSID =  L.LocationSID
WHERE 1=1
	AND V.WorkloadLogicFlag = 'Y'