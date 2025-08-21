CREATE TABLE [Config].[SPPRITE_OFRCare] (
    [ChecklistID] VARCHAR (5)   NULL,
    [Facility]    VARCHAR (510) NULL,
    [StartDate]   DATE          NULL,
    [EndDate]     DATE          NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SPPRITE_OFRCare]
    ON [Config].[SPPRITE_OFRCare];

