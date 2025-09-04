CREATE TABLE [BHIP].[MHTCAssignment] (
    [patienticn]            VARCHAR (50)  NULL,
    [mvipersonsid]          INT           NOT NULL,
    [patientname]           VARCHAR (200) NULL,
    [LastFour]              CHAR (4)      NULL,
    [checklistid]           NVARCHAR (30) NULL,
    [visitsid]              BIGINT        NULL,
    [healthfactordatetime]  DATETIME2 (7) NULL,
    [RN]                    BIGINT        NULL,
    [Note_Date]             DATETIME2 (7) NULL,
    [Note_Author]           VARCHAR (100) NULL,
    [Note_MHTC]             VARCHAR (255) NULL,
    [asgn_type]             VARCHAR (18)  NULL,
    [team]                  VARCHAR (50)  NULL,
    [TeamRole]              VARCHAR (100) NULL,
    [staffname]             VARCHAR (100) NULL,
    [relationshipstartdate] DATETIME      NULL
);
GO

CREATE CLUSTERED INDEX [CIX_MHTCAssignment]
    ON [BHIP].[MHTCAssignment]([mvipersonsid] ASC, [Note_Date] ASC) WITH(DATA_COMPRESSION = PAGE);
GO
