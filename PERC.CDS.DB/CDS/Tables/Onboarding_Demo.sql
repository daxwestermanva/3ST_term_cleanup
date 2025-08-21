CREATE TABLE [CDS].[Onboarding_Demo] (
    [DateSID]              INT           NULL,
    [Date]                 SMALLDATETIME NULL,
    [DateText]             VARCHAR (10)  NULL,
    [DayName]              VARCHAR (10)  NULL,
    [MonthName]            VARCHAR (10)  NULL,
    [MonthOfYear]          TINYINT       NULL,
    [CalendarYear]         SMALLINT      NULL,
    [FiscalYear]           SMALLINT      NULL,
    [FederalHoliday]       VARCHAR (50)  NULL,
    [DayOfMonth]           TINYINT       NULL,
    [IsWeekend]            VARCHAR (1)   NULL,
    [DaysLeftInFiscalYear] INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Onboarding_Demo]
    ON [CDS].[Onboarding_Demo];

