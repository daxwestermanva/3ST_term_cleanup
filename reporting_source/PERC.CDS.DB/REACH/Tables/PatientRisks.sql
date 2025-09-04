CREATE TABLE [REACH].[PatientRisks] (
    [MVIPersonSID]      INT         NULL,
    [Risk]              NVARCHAR (128) NULL,
    [PrintName]         NVARCHAR (255) NULL,
    [TimeFrame]         TINYINT        NULL,
    [RiskType]          VARCHAR (10)   NOT NULL,
    [EarliestTimeFrame] TINYINT        NULL
);


GO
CREATE CLUSTERED INDEX [CIX_ReachPtRisks_MVISID]
    ON [REACH].[PatientRisks]([MVIPersonSID] ASC) WITH (FILLFACTOR = 100, DATA_COMPRESSION = PAGE);

