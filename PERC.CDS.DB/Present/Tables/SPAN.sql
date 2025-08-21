CREATE TABLE [Present].[SPAN] (
    [PatientICN]                VARCHAR (50)  NULL,
    [MVIPersonSID]              INT           NULL,
    [SPANPatientID]             INT           NULL,
    [Sta3n]                     SMALLINT      NULL,
    [ChecklistID]               VARCHAR (5)   NULL,
    [EventID]                   BIGINT        NULL,
    [MethodType1]               VARCHAR (50)  NULL,
    [Method1]                   VARCHAR (150) NULL,
    [MethodComments1]           VARCHAR (MAX) NULL,
    [MethodType2]               VARCHAR (50)  NULL,
    [Method2]                   VARCHAR (150) NULL,
    [MethodComments2]           VARCHAR (MAX) NULL,
    [MethodType3]               VARCHAR (50)  NULL,
    [Method3]                   VARCHAR (150) NULL,
    [MethodComments3]           VARCHAR (MAX) NULL,
    [AdditionalMethodsReported] VARCHAR (10)  NULL,
    [DtEntered]                 DATE          NULL,
    [EnteredBy]                 VARCHAR (100) NULL,
    [EventDate]                 VARCHAR (50)  NULL,
    [EventType]                 VARCHAR (50)  NULL,
    [Outcome]                   VARCHAR (50)  NULL,
    [OutcomeComments]           VARCHAR (MAX) NULL,
    [VAProperty]                VARCHAR (10)  NULL,
    [Comments]                  VARCHAR (MAX) NULL,
    [SDVClassification]         VARCHAR (150) NULL,
    [ReportedBy]                VARCHAR (250) NULL
);


















GO



