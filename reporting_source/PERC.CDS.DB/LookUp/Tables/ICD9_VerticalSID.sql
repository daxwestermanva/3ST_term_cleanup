CREATE TABLE [LookUp].[ICD9_VerticalSID] (
    [ICD9Code]        VARCHAR (25)  NULL,
    [ICD9SID]         INT           NULL,
    [ICD9Description] VARCHAR (250) NULL,
    [DxCategory]      VARCHAR (100) NULL
);




GO
CREATE NONCLUSTERED INDEX [IX__LookUp_ICD9_Vertical_SID]
    ON [LookUp].[ICD9_VerticalSID]([ICD9SID] ASC);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_LookUp_ICD9_Vertical]
    ON [LookUp].[ICD9_VerticalSID];

