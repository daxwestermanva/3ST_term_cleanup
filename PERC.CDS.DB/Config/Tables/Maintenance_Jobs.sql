CREATE TABLE [Config].[Maintenance_Jobs] (
    [Schedule]      VARCHAR (20)  NULL,
    [Project]       VARCHAR (20)  NULL,
    [SpName]        VARCHAR (80)  NOT NULL,
    [Sequence]      INT           NULL,
    [StopOnFailure] BIT           NULL,
    [Comments]      VARCHAR (150) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Maintenance_Jobs]
    ON [Config].[Maintenance_Jobs];

