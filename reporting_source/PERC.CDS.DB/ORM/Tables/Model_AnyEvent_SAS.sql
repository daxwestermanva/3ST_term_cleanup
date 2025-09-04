CREATE TABLE [ORM].[Model_AnyEvent_SAS] (
    [Effect]      VARCHAR (35)     NOT NULL,
    [Value1]      INT              NULL,
    [Value2]      INT              NULL,
    [Value3]      VARCHAR (5)      NULL,
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
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Model_AnyEvent_SAS]
    ON [ORM].[Model_AnyEvent_SAS];

