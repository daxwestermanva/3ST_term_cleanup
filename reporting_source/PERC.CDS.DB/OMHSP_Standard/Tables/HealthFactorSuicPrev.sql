CREATE TABLE [OMHSP_Standard].[HealthFactorSuicPrev] (
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
    [PrintName]            VARCHAR (100) NULL,
    [OrderDesc]            INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HealthFactorSuicPrev]
    ON [OMHSP_Standard].[HealthFactorSuicPrev];

