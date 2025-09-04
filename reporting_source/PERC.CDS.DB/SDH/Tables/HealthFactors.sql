CREATE TABLE [SDH].[HealthFactors] (
    [PatientICN]           VARCHAR (50)  NULL,
    [MVIPersonSID]         INT           NOT NULL,
    [Sta3n]                SMALLINT      NULL,
    [ChecklistID]          NVARCHAR (30) NULL,
    [VisitSID]             BIGINT        NULL,
    [HealthFactorSID]      BIGINT        NULL,
    [DocFormActivitySID]   BIGINT        NULL,
    [HealthFactorDateTime] VARCHAR (16)  NULL,
    [Comments]             VARCHAR (255) NULL,
    [Category]             VARCHAR (100) NULL,
    [List]                 VARCHAR (50)  NOT NULL,
    [PrintName]            VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HealthFactors]
    ON [SDH].[HealthFactors];

