CREATE TABLE [Common].[InpatientRecords_002] (
    [MVIPersonSID]               INT           NULL,
    [StayId]                     BIGINT        NULL,
    [DerivedBedSectionRecordSID] BIGINT        NULL,
    [BSInDateTime]               DATETIME2 (0) NULL,
    [BsOutDateTime]              DATETIME2 (0) NULL,
    [uBSInDateTime]              DATETIME2 (0) NULL,
    [uBsOutDateTime]             DATETIME2 (0) NULL,
    [KeepFlag]                   BIGINT        NULL,
    [PatientPersonSID]           INT           NULL,
    [PTFCode]                    VARCHAR (12)  NULL,
    [Specialty]                  VARCHAR (50)  NULL,
    [MedicalService]             VARCHAR (50)  NULL,
    [Accommodation]              VARCHAR (50)  NULL,
    [BedSectionRecordSID]        BIGINT        NOT NULL,
    [SpecialtyTransferDateTime]  DATETIME2 (0) NULL,
    [TreatingSpecialtySID]       INT           NULL,
    [InpatientEncounterSID]      BIGINT        NOT NULL,
    [Sta6a]                      VARCHAR (12)  NULL,
    [StaPa]                      VARCHAR (12)  NULL,
    [Sta3n_EHR]                  SMALLINT      NOT NULL,
    [AdmitDateTime]              DATETIME2 (0) NULL,
    [DischargeDateTime]          DATETIME2 (0) NOT NULL,
    [PlaceOfDisposition]         VARCHAR (50)  NULL,
    [AMA]                        INT           NOT NULL,
    [AdmitDiagnosis]             VARCHAR (50)  NULL,
    [PrincipalDiagnosisSID]      INT           NULL,
    [PrincipalDiagnosisType]     VARCHAR (7)   NOT NULL,
    [PlaceOfDispositionCode]     VARCHAR (50)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_InpatientRecords_002]
    ON [Common].[InpatientRecords_002];

