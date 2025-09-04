CREATE TABLE [Maintenance].[DatabaseChangeLog] (
    [DatabaseChangeLogID] INT           IDENTITY (1, 1) NOT NULL,
    [FileName]            VARCHAR (MAX) NULL,
    [CreatedDateTime]     DATETIME      CONSTRAINT [DF_DatabaseChangeLog_CreatedDateTime] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_DatabaseChangeLog] PRIMARY KEY CLUSTERED ([DatabaseChangeLogID] ASC)
);

