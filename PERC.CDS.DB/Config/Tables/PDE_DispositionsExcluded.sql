CREATE TABLE [Config].[PDE_DispositionsExcluded] (
    [DispositionValue] VARCHAR (255) NULL,
    [SourceColumn]     VARCHAR (255) NULL,
    [SourceTable]      VARCHAR (255) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PDE_DispositionsExcluded]
    ON [Config].[PDE_DispositionsExcluded];

