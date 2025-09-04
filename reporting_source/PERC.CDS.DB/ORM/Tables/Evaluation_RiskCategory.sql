CREATE TABLE [ORM].[Evaluation_RiskCategory] (
    [PatientICN]       VARCHAR (50)  NULL,
    [RiskCategory]     INT           NOT NULL,
    [RiskCategoryDate] DATETIME      NOT NULL,
    [ChecklistID]      NVARCHAR (30) NULL,
    [MVIPersonSID]     INT           NULL
);








GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ORM_Evaluation_RiskCategory]
    ON [ORM].[Evaluation_RiskCategory];





