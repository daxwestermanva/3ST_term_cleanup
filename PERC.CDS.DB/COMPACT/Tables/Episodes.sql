CREATE TABLE [COMPACT].[Episodes] (
    [MVIPersonSID]               INT           NOT NULL,
    [ChecklistID_EpisodeBegin]   VARCHAR (5)   NULL,
    [EpisodeBeginDate]           DATE          NULL,
    [EpisodeEndDate]             DATE          NULL,
    [CommunityCare]              TINYINT       NULL,
    [EpisodeBeginSetting]        VARCHAR (15)  NULL,
    [InpatientEpisodeEndDate]    DATE          NULL,
    [OutpatientEpisodeBeginDate] DATE          NULL,
    [ActiveEpisode]              TINYINT       NULL,
    [ActiveEpisodeSetting]       CHAR (1)      NULL,
    [EpisodeTruncated]           TINYINT       NULL,
    [TruncateReason]             VARCHAR (30)  NULL,
    [EpisodeExtended]            TINYINT       NULL,
    [EpisodeRankDesc]            INT           NULL,
    [EncounterCodes]             VARCHAR (500) NULL,
    [TemplateStart]              TINYINT       NULL,
    [ConfirmedStart]             TINYINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Episodes]
    ON [COMPACT].[Episodes];

