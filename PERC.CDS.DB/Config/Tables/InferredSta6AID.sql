CREATE TABLE [Config].[InferredSta6AID] (
    [LocationIndicator] VARCHAR (100) NULL,
    [InferredVISN]      VARCHAR (100) NULL,
    [Sta6aID]           VARCHAR (100) NULL,
    [ChecklistID]       VARCHAR (5)   NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_InferredSta6AID]
    ON [Config].[InferredSta6AID];

