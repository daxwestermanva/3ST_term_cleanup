CREATE TABLE [PRF_HRS].[LookUp_NoteTitles] (
    [Facility]           NVARCHAR (255) NULL,
    [Sta3n]              SMALLINT       NULL,
    [DocumentDefinition] NVARCHAR (255) NULL,
    [StandardTitle]      NVARCHAR (255) NULL,
    [NoteTopic]          NVARCHAR (255) NULL,
    [NoteTopic2]         NVARCHAR (255) NULL,
    [NoteTopic3]         NVARCHAR (255) NULL,
    [NoteTopic4]         NVARCHAR (255) NULL,
    [NotesForOtherEtc]   NVARCHAR (255) NULL,
    [IntegStation]       NVARCHAR (255) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_LookUp_NoteTitles]
    ON [PRF_HRS].[LookUp_NoteTitles];

