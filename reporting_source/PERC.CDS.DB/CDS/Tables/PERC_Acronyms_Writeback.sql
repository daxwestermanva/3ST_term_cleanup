CREATE TABLE [CDS].[PERC_Acronyms_Writeback] (
    [Acronym]       VARCHAR (10)  NULL,
    [Definition]    VARCHAR (100) NULL,
    [Description]   VARCHAR (100) NULL,
    [DateSubmitted] DATETIME2 (7) NULL,
    [UserID]        VARCHAR (150) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PERC_Acronyms_Writeback]
    ON [CDS].[PERC_Acronyms_Writeback];

