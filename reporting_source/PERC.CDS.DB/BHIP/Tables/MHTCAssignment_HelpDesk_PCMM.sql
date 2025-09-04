CREATE TABLE [BHIP].[MHTCAssignment_HelpDesk_PCMM] (
    [MVIPersonsid]          INT           NULL,
    [PatientICN]            VARCHAR (50)  NULL,
    [checklistid]           NVARCHAR (10) NULL,
    [patientsid]            INT           NULL,
    [staffname]             VARCHAR (100) NULL,
    [TeamRole]              VARCHAR (80)  NULL,
    [team]                  VARCHAR (30)  NULL,
    [Teamfocus]             VARCHAR (80)  NULL,
    [relationshipstartdate] DATETIME      NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MHTCAssignment_HelpDesk_PCMM]
    ON [BHIP].[MHTCAssignment_HelpDesk_PCMM];

