CREATE TABLE [SBOSR].[ScreenEngage_PBI] (
    [MVIPersonSID]          INT           NULL,
    [PatientKey]            VARCHAR (100) NOT NULL,
    [CSSRSPositivePastYear] INT           NULL,
    [CSREHighPastYear]      INT           NULL,
    [CSREPastYear]          INT           NULL,
    [SafetyPlanDate]        DATE          NULL,
    [SafetyPlanPastYear]    INT           NULL,
    [FirearmAccess]         INT           NULL,
    [OpioidAccess]          INT           NULL,
    [PCLast3Mo]             INT           NULL,
    [PCLastYr]              INT           NULL,
    [MHLast3Mo]             INT           NULL,
    [MHLastYr]              INT           NULL,
    [SP2LastYr]             INT           NULL,
    [SP2RequestDate]        DATE          NULL,
    [ActiveEpisode]         INT           NULL,
    [MostRecentApptStop]    VARCHAR (100) NULL,
    [NextApptStop]          VARCHAR (100) NULL,
    [BHIP]                  INT           NULL,
    [PACT]                  INT           NULL,
    [ReferenceDate]         DATE          NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ScreenEngage_PBI]
    ON [SBOSR].[ScreenEngage_PBI];

