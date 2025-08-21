CREATE TABLE [Config].[Present_ProjectDisplayRequirement] (
    [ProjectName]   VARCHAR (25) NOT NULL,
    [RequirementID] INT          NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Present_ProjectDisplayRequirement]
    ON [Config].[Present_ProjectDisplayRequirement];

