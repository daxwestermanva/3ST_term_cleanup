CREATE TABLE [PRF].[Behavioral_EpisodeDates] (
    [MVIPersonSID]         INT           NOT NULL,
    [InitialActivation]    DATETIME2 (0) NULL,
    [TotalEpisodes]        TINYINT       NOT NULL,
    [FlagEpisode]          TINYINT       NOT NULL,
    [EpisodeBeginDateTime] DATETIME2 (0) NULL,
    [EpisodeEndDateTime]   DATETIME2 (0) NULL,
    [ActiveDays]           SMALLINT      NULL,
    [PreviousInactiveDays] SMALLINT      NULL,
    [CurrentActiveFlag]    BIT           NULL,
    [OwnerChecklistID]     VARCHAR (5)   NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Behavioral_EpisodeDates]
    ON [PRF].[Behavioral_EpisodeDates];

