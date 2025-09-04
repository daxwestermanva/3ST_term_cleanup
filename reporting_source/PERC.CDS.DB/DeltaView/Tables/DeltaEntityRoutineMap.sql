CREATE TABLE [DeltaView].[DeltaEntityRoutineMap] (
    [DeltaEntityRoutineMapId]   INT           IDENTITY (1, 1) NOT NULL,
    [DeltaEntityName]           VARCHAR (255) NOT NULL,
    [DeltaEntitySource]         VARCHAR (50)  NOT NULL,
    [RoutineName]               VARCHAR (255) NOT NULL,
    [DeltaKeySnapshotTableName] VARCHAR (255) NOT NULL,
    CONSTRAINT [PK_DeltaEntityRoutineMap] PRIMARY KEY CLUSTERED ([DeltaEntityRoutineMapId] ASC)
);



