CREATE TABLE [LookUp].[ICD10_Display] (
    [DxCategory]  VARCHAR (50) NULL,
    [ProjectType] VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_LookUp_ICD10Display]
    ON [LookUp].[ICD10_Display];

