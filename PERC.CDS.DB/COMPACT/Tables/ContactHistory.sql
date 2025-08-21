CREATE TABLE [COMPACT].[ContactHistory] (
    [ContactType]        VARCHAR (50)    NOT NULL,
    [MVIPersonSID]       INT             NOT NULL,
    [EpisodeRankDesc]    INT             NULL,
    [Sta3n_EHR]          INT             NULL,
    [Sta6a]              VARCHAR (50)    NULL,
    [ContactSID]         VARCHAR (50)    NULL,
    [ContactSIDType]     VARCHAR (18)    NOT NULL,
    [RxNumber]           VARCHAR (50)    NULL,
    [EncounterStartDate] DATETIME2 (3)   NULL,
    [EncounterEndDate]   DATETIME2 (3)   NULL,
    [Detail]             VARCHAR (200)   NULL,
    [StaffName]          VARCHAR (50)    NULL,
    [EncounterCodes]     VARCHAR (500)   NULL,
    [Template]           TINYINT         NULL,
    [CPTCodes_All]       VARCHAR (50)    NULL,
    [COMPACTCategory]    VARCHAR (50)    NULL,
    [COMPACTAction]      VARCHAR (50)    NULL,
    [TotalCharge]        DECIMAL (19, 4) NULL,
    [BriefDescription]   VARCHAR (50)    NULL,
    [ChargeRemoveReason] VARCHAR (50)    NULL
);












GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ContactHistory]
    ON [COMPACT].[ContactHistory];

