CREATE TABLE [BHIP].[Risk_PBI] (
    [MVIPersonSID]          INT            NULL,
    [Actionable]            INT            NULL,
    [ActionExpected]        VARCHAR (50)   NULL,
    [EventDate]             DATE           NULL,
    [EventValue]            VARCHAR (200)  NULL,
    [RiskFactor]            VARCHAR (70)   NULL,
    [TobaccoPositiveScreen] INT            NULL,
    [ChecklistID]           NVARCHAR (30)  NULL,
    [Code]                  NVARCHAR (255) NULL,
    [Facility]              NVARCHAR (255) NULL,
    [ActionExpected_Sort]   INT            NULL,
    [QuickViewDisplay]      INT            NULL
);

