CREATE TABLE [ORM].[DefinitionsReportStopCode] (
    [StopCodeSID]         BIGINT         NOT NULL,
    [Sta3n]               SMALLINT       NOT NULL,
    [StopCodeDescription] VARCHAR (100)  NULL,
    [StopCode]            VARCHAR (100)  NULL,
    [stop]                NVARCHAR (128) NULL,
    [stopvalue]           SMALLINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DefinitionsReportStopCode]
    ON [ORM].[DefinitionsReportStopCode];

