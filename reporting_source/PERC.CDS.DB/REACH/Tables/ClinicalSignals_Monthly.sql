CREATE TABLE [REACH].[ClinicalSignals_Monthly] (
    [MVIPersonSID]               INT             NOT NULL,
    [VariableID]                 INT             NOT NULL,
    [Variable]                   VARCHAR (250)   NOT NULL,
    [VariableValue]              VARCHAR (200)   NULL,
    [ComputationalVariableValue] DECIMAL (18, 5) NOT NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ClinicalSignals_Monthly]
    ON [REACH].[ClinicalSignals_Monthly];

