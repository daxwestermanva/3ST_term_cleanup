CREATE TABLE [BHIP].[MHTCAssignment_HelpDesk_Note] (
    [sta3n]         SMALLINT      NOT NULL,
    [patientsid]    INT           NULL,
    [patientname]   VARCHAR (200) NULL,
    [patienticn]    VARCHAR (50)  NULL,
    [NoteTitle]     VARCHAR (500) NULL,
    [Note_Author]   VARCHAR (100) NULL,
    [EntryDateTime] DATETIME2 (0) NULL,
    [tiustatus]     VARCHAR (50)  NULL
);




GO
