CREATE TABLE [DeltaView].[HighWatermarkConfig] (
    [HighWatermarkConfigId]      INT           IDENTITY (1, 1) NOT NULL,
    [DeltaEntityName]            VARCHAR (255) NOT NULL,
    [SourceTable]                VARCHAR (255) NOT NULL,
    [SourceSystem]               VARCHAR (50)  NOT NULL,
    [ExtractBatchID]             BIGINT        NOT NULL,
    [ETLBatchID]                 INT           NOT NULL,
    [DWPhysicalTableName]        VARCHAR (255) NOT NULL,
    [ETLBatchLoadedDateTime]     DATETIME2 (0) NULL,
    [ExtractBatchLoadedDateTime] DATETIME2 (0) NULL,
    [DWFullTableName]            VARCHAR (255) NOT NULL,
    [ExecutionLogID]             INT           NOT NULL,
    [CreateDate]                 DATETIME      NOT NULL,
    [EditDate]                   DATETIME      NOT NULL,
    CONSTRAINT [PK_HighWatermarkConfig] PRIMARY KEY CLUSTERED ([HighWatermarkConfigId] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [IDX_NC_HighWatermarkConfig_AK]
    ON [DeltaView].[HighWatermarkConfig]([DeltaEntityName] ASC, [SourceTable] ASC, [SourceSystem] ASC, [ExecutionLogID] ASC);

