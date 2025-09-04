CREATE TABLE [Maintenance].[Jobs_V02] (
    [SpName]        VARCHAR (80)  NOT NULL,
    [Schedule]      VARCHAR (9)   NULL,
    [Group]         VARCHAR (15)  NULL,
    [Order]         TINYINT       NULL,
    [Sequence]      CHAR (8)      NULL,
    [Project]       VARCHAR (20)  NULL,
    [StopOnFailure] BIT           NULL,
    [Comments]      VARCHAR (150) NULL
);



