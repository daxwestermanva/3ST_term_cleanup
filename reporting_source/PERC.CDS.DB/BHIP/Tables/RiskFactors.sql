CREATE TABLE [BHIP].[RiskFactors] (
    [MVIPersonSID]          INT            NOT NULL,
    [RiskFactor]            VARCHAR (100)  NULL,
    [ChecklistID]           VARCHAR (5)    NULL,
    [Facility]              VARCHAR (100)  NULL,
    [EventValue]            VARCHAR (200)  NULL,
    [EventDate]             DATE           NULL,
    [LastBHIPContact]       DATE           NULL,
    [Actionable]            INT            NULL,
    [OverdueFlag]           INT            NULL,
    [ActionExpected]        VARCHAR (50)   NULL,
    [ActionLabel]           VARCHAR (50)   NULL,
    [Code]                  NVARCHAR (255) NULL,
    [TobaccoPositiveScreen] INT            NULL
);




GO
