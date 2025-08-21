CREATE TABLE [REACH].[WritebackHistoric] (
    [PatientSID]          INT           NULL,
    [ChecklistID]         VARCHAR (5)   NULL,
    [QuestionNumber]      INT           NULL,
    [Question]            VARCHAR (250) NULL,
    [QuestionType]        VARCHAR (37)  NULL,
    [QuestionStatus]      INT           NULL,
    [EntryDate]           DATETIME      NULL,
    [NtLogin]             VARCHAR (100) NULL,
    [UserName]            VARCHAR (100) NULL,
    [UserEmail]           VARCHAR (100) NULL,
    [EntryDatePatientICN] VARCHAR (50)  NULL
);






GO
CREATE CLUSTERED INDEX [CIX_ReachWB_PatientSID]
    ON [REACH].[WritebackHistoric]([PatientSID] ASC) WITH (DATA_COMPRESSION = PAGE);

