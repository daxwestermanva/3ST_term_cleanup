CREATE TABLE [BHIP].[MHTCAssignment_HelpDesk] (
    [Checklistid]           NVARCHAR (10) NULL,
    [patienticn]            VARCHAR (50)  NULL,
    [patientname]           VARCHAR (200) NULL,
    [LastFour]              CHAR (4)      NULL,
    [healthfactordatetime]  DATETIME2 (0) NULL,
    [Note_Date]             DATETIME2 (0) NULL,
    [Note_MHTC]             VARCHAR (255) NULL,
    [asgn_type]             VARCHAR (18)  NULL,
    [asgn_reason]           VARCHAR (68)  NULL,
    [asgn_reason_Comments]  VARCHAR (255) NULL,
    [pcmm_checklistid]      NVARCHAR (10) NULL,
    [team]                  VARCHAR (30)  NULL,
    [TeamRole]              VARCHAR (80)  NULL,
    [staffname]             VARCHAR (100) NULL,
    [relationshipstartdate] DATETIME      NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MHTCAssignment_HelpDesk]
    ON [BHIP].[MHTCAssignment_HelpDesk];

