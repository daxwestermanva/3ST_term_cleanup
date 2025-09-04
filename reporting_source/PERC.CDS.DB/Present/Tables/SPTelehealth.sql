CREATE TABLE [Present].[SPTelehealth] (
    [MVIPersonSID]          INT          NOT NULL,
    [IntakeDate]            VARCHAR (16) NULL,
    [TemplateGroup]         VARCHAR (55) NULL,
    [FirstSessionDate]      VARCHAR (16) NULL,
    [MostRecentSessionDate] VARCHAR (16) NULL,
    [DischargeDate]         VARCHAR (16) NULL,
    [DischargeType]         VARCHAR (10) NULL,
    [RowNum]                SMALLINT     NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SPTelehealth]
    ON [Present].[SPTelehealth];

