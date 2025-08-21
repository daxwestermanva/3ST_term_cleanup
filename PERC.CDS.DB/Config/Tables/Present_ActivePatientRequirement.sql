CREATE TABLE [Config].[Present_ActivePatientRequirement] (
    [RequirementID]   INT           NOT NULL,
    [RequirementName] VARCHAR (25)  NOT NULL,
    [Description]     VARCHAR (250) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Present_ActivePatientRequirement]
    ON [Config].[Present_ActivePatientRequirement];

