CREATE TABLE [LookUp].[ICD9Proc] (
    [ICD9ProcedureSID]                BIGINT         NOT NULL,
    [Sta3n]                           SMALLINT       NOT NULL,
    [ICD9ProcedureDescription]        VARCHAR (8000) NULL,
    [ICD9ProcedureShort]              VARCHAR (100)  NULL,
    [ICD9ProcedureCode]               VARCHAR (100)  NULL,
    [InactiveFlag]                    VARCHAR (10)   NULL,
    [Psych_Therapy_ICD9Proc]          SMALLINT       NULL,
    [RM_ActiveTherapies_ICD9Proc]     SMALLINT       NULL,
    [RM_OccupationalTherapy_ICD9Proc] SMALLINT       NULL,
    [RM_OtherTherapy_ICD9Proc]        SMALLINT       NULL,
    [CAM_ICD9Proc]                    SMALLINT       NULL
);
GO
CREATE CLUSTERED INDEX [CIX_LookUp_ICD9ProcSID]
    ON [LookUp].[ICD9Proc]([ICD9ProcedureSID] ASC) WITH (DATA_COMPRESSION = PAGE);
GO
