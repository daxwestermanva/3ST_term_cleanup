CREATE TABLE [App].[Log_ContainerList] (
    [PackageID]               VARCHAR (50) NULL,
    [TaskID]                  VARCHAR (50) NULL,
    [PackageName]             VARCHAR (50) NULL,
    [TaskName]                VARCHAR (50) NULL,
    [TaskDesc]                VARCHAR (50) NULL,
    [SSISDBServerExecutionID] INT          NULL,
    [ContainerListID]         INT          IDENTITY (1, 1) NOT NULL
)
WITH (DATA_COMPRESSION = PAGE);


GO
