CREATE TABLE [ORM].[Model_Overdose_Random_SAS] (
    [Effect]      VARCHAR (25)     NOT NULL,
    [Estimate]    DECIMAL (38, 15) NOT NULL,
    [StdErr]      DECIMAL (38, 15) NULL,
    [DF]          INT              NULL,
    [tValue]      DECIMAL (38, 15) NULL,
    [Probt]       DECIMAL (38, 15) NULL,
    [ModelDate]   DATE             NULL,
    [ModelFY]     INT              NULL,
    [SQLLoadDate] DATE             NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Model_Overdose_Random_SAS]
    ON [ORM].[Model_Overdose_Random_SAS];

