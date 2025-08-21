CREATE TABLE [SDH].[IPV_Screen] (
    [MVIPersonSID]            INT           NOT NULL,
    [Sta3n]                   SMALLINT      NULL,
    [ChecklistID]             NVARCHAR (30) NULL,
    [VisitSID]                BIGINT        NULL,
    [ScreenDateTime]          VARCHAR (16)  NULL,
    [ScreeningOccurred]       TINYINT       NULL,
    [ScreeningScore]          TINYINT       NULL,
    [Physical]                TINYINT       NULL,
    [Insult]                  TINYINT       NULL,
    [Scream]                  TINYINT       NULL,
    [Threaten]                TINYINT       NULL,
    [Force]                   TINYINT       NULL,
    [DangerScreeningOccurred] TINYINT       NULL,
    [ViolenceIncreased]       TINYINT       NULL,
    [Choked]                  TINYINT       NULL,
    [BelievesMayBeKilled]     TINYINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_IPV_Screen]
    ON [SDH].[IPV_Screen];

