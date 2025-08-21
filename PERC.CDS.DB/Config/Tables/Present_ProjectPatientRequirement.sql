CREATE TABLE [Config].[Present_ProjectPatientRequirement] (
    [ProjectName]   VARCHAR (25) NOT NULL,
    [RequirementID] INT          NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Present_ProjectPatientRequirement]
    ON [Config].[Present_ProjectPatientRequirement];

