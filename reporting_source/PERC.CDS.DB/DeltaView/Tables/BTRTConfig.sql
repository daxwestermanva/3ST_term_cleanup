CREATE TABLE [DeltaView].[BTRTConfig] (
    [BTRTConfigId]                  INT            IDENTITY (1, 1) NOT NULL,
    [DeltaEntityName]               VARCHAR (255)  NOT NULL,
    [BaseTableName]                 VARCHAR (255)  NOT NULL,
    [BaseTablePK]                   VARCHAR (255)  NOT NULL,
    [RelatedTableName]              VARCHAR (255)  NOT NULL,
    [RelatedTablePK]                VARCHAR (255)  NOT NULL,
    [BaseToRelatedType]             VARCHAR (15)   NOT NULL,
    [BaseToRelatedJoinSpec]         VARCHAR (1000) NOT NULL,
    [IsReferencingTableCompositePK] BIT            NULL,
    [IsBaseTableRootEntity]         BIT            NOT NULL,
    [BaseTableWhere]                VARCHAR (4000) NULL,
    [RelatedTableWhere]             VARCHAR (4000) NULL,
    [RelatedTableWhereDELETE]       VARCHAR (4000) NULL,
    CONSTRAINT [PK_BTRTConfig] PRIMARY KEY CLUSTERED ([BTRTConfigId] ASC)
);



