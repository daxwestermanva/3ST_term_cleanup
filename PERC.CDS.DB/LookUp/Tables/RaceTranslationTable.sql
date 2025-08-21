CREATE TABLE [LookUp].[RaceTranslationTable] (
    [InboundRace]  VARCHAR (50) NULL,
    [StandardRace] VARCHAR (50) NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RaceTranslationTable]
    ON [LookUp].[RaceTranslationTable];

