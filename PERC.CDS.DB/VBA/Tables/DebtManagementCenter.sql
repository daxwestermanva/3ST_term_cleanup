CREATE TABLE [VBA].[DebtManagementCenter] (
    [MVIPersonSID]             INT           NOT NULL,
    [PatientICN]               VARCHAR (50)  NULL,
    [ADAM_KEY]                 CHAR (25)     NULL,
    [TOTAL_AR_AMOUNT]          INT           NULL,
    [DEDUCTION_DESC]           VARCHAR (500) NULL,
    [MostRecentContact_Date]   DATE          NULL,
    [MostRecentContact_Letter] VARCHAR (500) NULL,
    [Patient_Debt_Count]       INT           NULL,
    [Patient_Debt_Sum]         INT           NULL,
    [CPDeduction]              BIT           NULL,
    [FirstDemandDate]          DATE          NULL,
    [TreasuryOffsetDate]       DATE          NULL,
    [ReferToCSDate]            DATE          NULL,
    [DisplayMessage]           TINYINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DebtManagementCenter]
    ON [VBA].[DebtManagementCenter];

