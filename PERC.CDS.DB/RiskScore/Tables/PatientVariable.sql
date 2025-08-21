CREATE TABLE [RiskScore].[PatientVariable] (
    [MVIPersonSID]  INT             NOT NULL,
    [VariableID]    SMALLINT        NOT NULL,
    [VariableValue] DECIMAL (15, 8) NULL,
    [ImputedFlag]   BIT             NULL,
    [SourceEHR]     VARCHAR (3)     NULL,
    CONSTRAINT [PK_PatientVariable] PRIMARY KEY CLUSTERED ([MVIPersonSID] ASC, [VariableID] ASC)
);













