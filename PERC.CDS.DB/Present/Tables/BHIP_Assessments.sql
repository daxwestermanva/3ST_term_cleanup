CREATE TABLE [Present].[BHIP_Assessments] (
    [ChecklistID]   NVARCHAR (10) NULL,
    [MVIPersonSID]  INT           NOT NULL,
    [VisitDateTime] DATETIME2 (0) NULL,
    [VisitSID]      BIGINT        NULL,
    [AssessmentRN]  INT           NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_BHIP_Assessments]
    ON [Present].[BHIP_Assessments];

