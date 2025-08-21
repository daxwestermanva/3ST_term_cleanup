CREATE TABLE [Config].[PRF_HRS_CaringLetterRollout] (
    [ChecklistID] VARCHAR (5) NOT NULL,
    [StartDate]   DATE        NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PRF_HRS_CaringLetterRollout]
    ON [Config].[PRF_HRS_CaringLetterRollout];

