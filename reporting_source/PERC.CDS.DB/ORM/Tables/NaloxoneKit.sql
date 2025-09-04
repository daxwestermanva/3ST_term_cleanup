CREATE TABLE [ORM].[NaloxoneKit] (
    [MVIPersonSID]     INT           NOT NULL,
    [Sta3n]            SMALLINT      NULL,
    [Sta6a]            VARCHAR (50)  NULL,
    [DrugNameWithDose] VARCHAR (100) NULL,
    [ReleaseDateTime]  DATETIME2 (0) NULL,
    [MostRecentFill]   DATETIME2 (0) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_NaloxoneKit]
    ON [ORM].[NaloxoneKit];

