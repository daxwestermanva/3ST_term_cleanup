CREATE TABLE [PRF_HRS].[InpatDetail] (
    [MVIPersonSID]                   INT            NOT NULL,
    [InitialActivation]              DATETIME2 (7)  NULL,
    [LastActionDateTime]             DATETIME2 (0)  NULL,
    [AdmitDateTime]                  DATETIME2 (0)  NULL,
    [DischargeDateTime]              DATETIME2 (0)  NULL,
    [BsInDateTime]                   DATETIME2 (0)  NULL,
    [BsOutDateTime]                  DATETIME2 (0)  NULL,
    [BedSection]                     VARCHAR (15)   NULL,
    [Sta6a]                          VARCHAR (50)   NULL,
    [ICD10Code]                      VARCHAR (100)  NULL,
    [ICD10Description]               VARCHAR (8000) NULL,
    [FlaggedInpt]                    INT            NOT NULL,
    [BedSectionName]                 VARCHAR (100)  NULL,
    [MentalHealth_TreatingSpecialty] SMALLINT       NULL,
    [RRTP_TreatingSpecialty]         SMALLINT       NULL
);












GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_InpatDetail]
    ON [PRF_HRS].[InpatDetail];

