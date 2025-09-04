CREATE TABLE [CHOICE].[Prescriptions] (
    [FillRemarks] VARCHAR (5000) NULL,
    [RxOutpatSID] BIGINT         NULL,
    [ProviderSID] BIGINT         NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Prescriptions]
    ON [CHOICE].[Prescriptions];

