CREATE TABLE [Common].[InpatientRecords] (
    [MVIPersonSID]               INT           NOT NULL,
    [InpatientEncounterSID]      BIGINT        NOT NULL,
    [PatientPersonSID]           INT           NULL,
    [Census]                     BIT           NULL,
    [AdmitDateTime]              DATETIME2 (0) NULL,
    [DischargeDateTime]          DATETIME2 (0) NULL,
    [MedicalService]             VARCHAR (100) NULL,
    [Accommodation]              VARCHAR (100) NULL,
    [TreatingSpecialtySID]       BIGINT        NULL,
    [BsInDateTime]               DATETIME2 (0) NULL,
    [BsOutDateTime]              DATETIME2 (0) NULL,
    [BedSectionRecordSID]        BIGINT        NULL,
    [DerivedBedSectionRecordSID] BIGINT        NULL,
    [PlaceOfDisposition]         VARCHAR (50)  NULL,
    [AMA]                        BIT           NULL,
    [AdmitDiagnosis]             VARCHAR (50)  NULL,
    [PrincipalDiagnosisICD10SID] INT           NULL,
    [PrincipalDiagnosisICD9SID]  INT           NULL,
    [Sta6a]                      VARCHAR (50)  NULL,
    [ChecklistID]                VARCHAR (5)   NULL,
    [LastRecord]                 BIT           NULL,
    [Sta3n_EHR]                  SMALLINT      NULL,
    [UpdateDate]                 DATETIME      NOT NULL,
    [ICD10Code]                  VARCHAR (50)  NULL,
    [PlaceOfDispositionCode]     VARCHAR (50)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_InpatientRecords]
    ON [Common].[InpatientRecords];

