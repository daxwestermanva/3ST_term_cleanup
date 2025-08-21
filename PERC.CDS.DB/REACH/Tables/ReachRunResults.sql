CREATE TABLE [REACH].[ReachRunResults] (
    [ProcedureName]   NVARCHAR (256) NULL,
    [ValidationType]  NVARCHAR (256) NULL,
    [Results]         NVARCHAR (256) NULL,
    [RunDate]         DATETIME       NULL,
    [ErrorFlag]       INT            NULL,
    [ErrorResolution] NVARCHAR (256) DEFAULT (NULL) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ReachRunResults]
    ON [REACH].[ReachRunResults];

