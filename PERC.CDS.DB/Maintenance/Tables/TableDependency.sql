CREATE TABLE [Maintenance].[TableDependency] (
    [DatabaseName]     VARCHAR (21)   NULL,
    [SchemaName]       [sysname]      NULL,
    [Name]             [sysname]      NULL,
    [ProcDescription]  NVARCHAR (MAX) NULL,
    [ProcAuthor]       NVARCHAR (MAX) NULL,
    [TABLE_CATALOG]    VARCHAR (21)   NULL,
    [TableName]        NVARCHAR (279) NULL,
    [ObjectType]       VARCHAR (7)    NULL,
    [create_date]      DATETIME       NULL,
    [modify_date]      DATETIME       NULL,
    [Table_schema]     [sysname]      NULL,
    [CreateFlag]       INT            NULL,
    [Table_Name_Short] [sysname]      NULL
)
WITH (DATA_COMPRESSION = PAGE);


GO
