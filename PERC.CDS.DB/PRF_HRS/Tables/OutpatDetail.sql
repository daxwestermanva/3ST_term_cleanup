CREATE TABLE [PRF_HRS].[OutpatDetail] (
    [MVIPersonSID]           INT           NULL,
    [EpisodeBeginDateTime]   DATETIME2 (7) NULL,
    [EpisodeEndDateTime]     DATETIME2 (7) NULL,
    [OutpatDateTime]         DATETIME2 (7) NULL,
    [PrimaryStopCode]        VARCHAR (100) NULL,
    [PrimaryStopCodeName]    VARCHAR (100) NULL,
    [SecondaryStopCode]      VARCHAR (100) NULL,
    [SecondaryStopCodeName]  VARCHAR (100) NULL,
    [AppointmentStatusAbbrv] VARCHAR (50)  NULL,
    [AppointmentStatus]      VARCHAR (50)  NULL,
    [CancellationReason]     VARCHAR (50)  NULL,
    [CancelDateTime]         DATETIME2 (7) NULL,
    [CancellationRemarks]    VARCHAR (255) NULL,
    [CancelTiming]           INT           NULL,
    [VisitSID]               BIGINT        NULL,
    [ProviderSID]            INT           NULL,
    [StaffName]              VARCHAR (100) NULL,
    [Sta3n]                  INT           NULL,
    [Sta6a]                  VARCHAR (50)  NULL,
    [DivisionName]           VARCHAR (100) NULL,
    [Location]               VARCHAR (50)  NULL,
    [ChecklistID]            NVARCHAR (30) NULL,
    [WorkloadLogicFlag]      CHAR (1)      NULL,
    [CPTCode_Display]        VARCHAR (50)  NULL,
    [HRF_ApptCategory]       TINYINT       NULL,
    [Inelig_Category]        TINYINT       NULL
);
















GO
CREATE CLUSTERED INDEX [PRF_HRSoutpat]
    ON [PRF_HRS].[OutpatDetail]([MVIPersonSID] ASC) WITH (FILLFACTOR = 100, DATA_COMPRESSION = PAGE);

