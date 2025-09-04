CREATE TABLE [LookUp].[SurveyColor] (
    [SurveyName] VARCHAR (50) NULL,
    [Color]      VARCHAR (50) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SurveyColor]
    ON [LookUp].[SurveyColor];

