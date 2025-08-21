CREATE TABLE [LookUp].[ICD10_VerticalSID] (
    [ICD10SID]         INT           NULL,
    [ICD10Code]        VARCHAR (25)  NULL,
    [ICD10Description] VARCHAR (250) NULL,
    [DxCategory]       VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_LookUp_ICD10_VerticalSID]
    ON [LookUp].[ICD10_VerticalSID];

