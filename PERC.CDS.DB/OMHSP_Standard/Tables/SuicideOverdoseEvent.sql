CREATE TABLE [OMHSP_Standard].[SuicideOverdoseEvent] (
    [MVIPersonSID]              INT           NULL,
    [SPANPatientID]             INT           NULL,
    [SPANEventID]               INT           NULL,
    [PatientICN]                VARCHAR (50)  NULL,
    [VisitSID]                  BIGINT        NULL,
    [DocFormActivitySID]        BIGINT        NULL,
    [Sta3n]                     INT           NULL,
    [ChecklistID]               VARCHAR (5)   NULL,
    [EntryDateTime]             DATE          NULL,
    [DataSource]                VARCHAR (55)  NULL,
    [EventDate]                 VARCHAR (MAX) NULL,
    [EventDateFormatted]        DATE          NULL,
    [EventType]                 VARCHAR (50)  NULL,
    [Intent]                    VARCHAR (12)  NULL,
    [Setting]                   VARCHAR (80)  NULL,
    [SettingComments]           VARCHAR (MAX) NULL,
    [SDVClassification]         VARCHAR (100) NULL,
    [VAProperty]                VARCHAR (7)   NULL,
    [SevenDaysDx]               VARCHAR (7)   NULL,
    [Preparatory]               VARCHAR (7)   NULL,
    [Interrupted]               VARCHAR (15)  NULL,
    [InterruptedComments]       VARCHAR (MAX) NULL,
    [Injury]                    VARCHAR (7)   NULL,
    [InjuryComments]            VARCHAR (MAX) NULL,
    [Outcome1]                  VARCHAR (50)  NULL,
    [Outcome1Comments]          VARCHAR (MAX) NULL,
    [Outcome2]                  VARCHAR (50)  NULL,
    [Outcome2Comments]          VARCHAR (MAX) NULL,
    [MethodType1]               VARCHAR (55)  NULL,
    [Method1]                   VARCHAR (55)  NULL,
    [MethodComments1]           VARCHAR (MAX) NULL,
    [MethodType2]               VARCHAR (55)  NULL,
    [Method2]                   VARCHAR (55)  NULL,
    [MethodComments2]           VARCHAR (MAX) NULL,
    [MethodType3]               VARCHAR (55)  NULL,
    [Method3]                   VARCHAR (55)  NULL,
    [MethodComments3]           VARCHAR (MAX) NULL,
    [AdditionalMethodsReported] VARCHAR (3)   NULL,
    [Comments]                  VARCHAR (MAX) NULL,
    [ODProvReview]              BIT           NULL,
    [ODReviewDate]              DATE          NULL,
    [Overdose]                  BIT           NULL,
    [Fatal]                     BIT           NULL,
    [PreparatoryBehavior]       BIT           NULL,
    [UndeterminedSDV]           BIT           NULL,
    [SuicidalSDV]               BIT           NULL,
    [EventOrderDesc]            INT           NULL,
    [AnyEventOrderDesc]         INT           NULL
);

















