CREATE TABLE [Config].[Risk_VariableClinicalConcepts] (
    [OriginalSource]     NVARCHAR (255) NULL,
    [REACHExcluded]      NVARCHAR (255) NULL,
    [Predictor]          FLOAT (53)     NULL,
    [Outcome]            FLOAT (53)     NULL,
    [MaxLookBack]        NVARCHAR (MAX) NULL,
    [MaxLookForward]     NVARCHAR (MAX) NULL,
    [Domain]             NVARCHAR (255) NULL,
    [Location]           NVARCHAR (255) NULL,
    [Source]             NVARCHAR (255) NULL,
    [Description]        VARCHAR (MAX)  NULL,
    [Value]              NVARCHAR (255) NULL,
    [InstanceVariableID] FLOAT (53)     NULL,
    [InstanceVariable]   NVARCHAR (255) NULL,
    [Ready]              FLOAT (53)     NULL
);

