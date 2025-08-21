CREATE TABLE [LookUp].[NationalDrug_Vertical] (
    [NationalDrugSID] BIGINT       NOT NULL,
    [VUID]            VARCHAR (50) NULL,
    [Sta3n]           SMALLINT     NULL,
    [DrugCategory]    VARCHAR (50) NULL
);

GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_NationalDrugVertical]
    ON [LookUp].[NationalDrug_Vertical];
GO
