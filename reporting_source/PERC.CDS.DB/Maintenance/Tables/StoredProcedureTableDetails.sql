CREATE TABLE [Maintenance].[StoredProcedureTableDetails] (
    [name]               [sysname]      NULL,
    [ProcDescription]    NVARCHAR (MAX) NULL,
    [ProcAuthor]         NVARCHAR (MAX) NULL,
    [TableCreatedByProc] NVARCHAR (MAX) NULL,
    [TABLE_CATALOG]      VARCHAR (21)   NOT NULL,
    [TableName]          NVARCHAR (279) NOT NULL,
    [create_date]        INT            NULL,
    [modify_date]        INT            NULL,
    [Table_schema]       [sysname]      NOT NULL,
    [CreateFlag]         INT            NOT NULL
);

