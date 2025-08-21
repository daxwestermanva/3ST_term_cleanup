CREATE TABLE [RiskScore].[PatientRiskScore] (
    [MVIPersonSID]        INT            NOT NULL,
    [ModelID]             TINYINT        NOT NULL,
    [HypotheticalModelID] TINYINT        NULL,
    [RiskScore]           DECIMAL (7, 6) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PatientRiskScore]
    ON [RiskScore].[PatientRiskScore];

