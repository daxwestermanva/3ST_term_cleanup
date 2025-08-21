CREATE TABLE [ORM].[Visit] (
    [MVIPersonSID]          INT           NULL,
    [Psych_Therapy_Key]     INT           NOT NULL,
    [Psych_Therapy_Date]    DATETIME2 (0) NULL,
    [Psych_Assessment_Key]  INT           NOT NULL,
    [Psych_Assessment_Date] DATETIME2 (0) NULL
);










GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Visit]
    ON [ORM].[Visit];

