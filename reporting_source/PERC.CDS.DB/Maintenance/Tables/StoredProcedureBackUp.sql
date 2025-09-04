CREATE TABLE [Maintenance].[StoredProcedureBackUp] (
    [DatabaseName] VARCHAR (150)  NULL,
    [name]         [sysname]      NOT NULL,
    [SchemaName]   VARCHAR (15)   NULL,
    [definition]   NVARCHAR (MAX) NULL,
    [BackUpDate]   DATETIME       NOT NULL
)
WITH (DATA_COMPRESSION = PAGE);


GO
