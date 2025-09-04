CREATE TABLE [DeltaView].[RoutineMasterETL] (
    [RoutineMasterETLId] INT           IDENTITY (1, 1) NOT NULL,
    [RoutineName]        VARCHAR (255) NOT NULL,
    [ExtractType]        VARCHAR (50)  NULL,
    [IsEnabled]          BIT           NULL,
    CONSTRAINT [PK_RoutineMasterETL] PRIMARY KEY CLUSTERED ([RoutineMasterETLId] ASC)
);



