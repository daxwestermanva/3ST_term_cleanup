CREATE TABLE [SUD].[Templates] (
    [mvipersonsid]         INT           NOT NULL,
    [Sta3n]                SMALLINT      NULL,
    [checklistid]          NVARCHAR (10) NULL,
    [visitsid]             BIGINT        NULL,
    [HealthFactorDTAType]  VARCHAR (250) NULL,
    [HealthFactorSID]      BIGINT        NULL,
    [DocFormActivitySID]   BIGINT        NULL,
    [healthfactordatetime] DATETIME2 (0) NULL,
    [Category]             VARCHAR (100) NULL,
    [List]                 VARCHAR (50)  NOT NULL,
    [PrintName]            VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Template]
    ON [SUD].[Templates];

