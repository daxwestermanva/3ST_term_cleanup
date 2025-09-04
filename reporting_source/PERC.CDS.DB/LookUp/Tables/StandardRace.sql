CREATE TABLE [LookUp].[StandardRace] (
    [RaceName] VARCHAR (45) NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_StandardRace]
    ON [LookUp].[StandardRace];

