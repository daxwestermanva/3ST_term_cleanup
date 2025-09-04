CREATE TABLE [REACH].[PatientReport] (
    [MVIPersonSID]                       INT             NULL,
    [PatientSID]                         INT             NULL,
    [ChecklistID]                        VARCHAR (5)     NULL,
    [RiskScoreSuicide]                   NUMERIC (38, 9) NULL,
    [RiskRanking]                        BIGINT          NULL,
    [Top01Percent]                       BIT             NOT NULL,
    [DateEnteredDashboard]               DATE            NULL,
    [PCFutureAppointmentDateTime_ICN]    DATETIME2 (0)   NULL,
    [PCFuturePrimaryStopCode_ICN]        VARCHAR (5)     NULL,
    [PCFutureStopCodeName_ICN]           VARCHAR (100)   NULL,
    [PCFutureAppointmentFacility_ICN]    VARCHAR (100)   NULL,
    [MHFutureAppointmentDateTime_ICN]    DATETIME2 (0)   NULL,
    [MHFuturePrimaryStopCode_ICN]        VARCHAR (5)     NULL,
    [MHFutureStopCodeName_ICN]           VARCHAR (100)   NULL,
    [MHFutureAppointmentFacility_ICN]    VARCHAR (100)   NULL,
    [OtherFutureAppointmentDateTime_ICN] DATETIME2 (0)   NULL,
    [OtherFuturePrimaryStopCode_ICN]     VARCHAR (5)     NULL,
    [OtherFutureStopCodeName_ICN]        VARCHAR (100)   NULL,
    [OtherFutureAppointmentFacility_ICN] VARCHAR (100)   NULL,
    [MHRecentVisitDate_ICN]              DATETIME2 (0)   NULL,
    [MHRecentStopCode_ICN]               VARCHAR (5)     NULL,
    [MHRecentStopCodeName_ICN]           VARCHAR (100)   NULL,
    [MHRecentSta3n_ICN]                  SMALLINT        NULL,
    [PCRecentVisitDate_ICN]              DATETIME2 (0)   NULL,
    [PCRecentStopCode_ICN]               VARCHAR (5)     NULL,
    [PCRecentStopCodeName_ICN]           VARCHAR (100)   NULL,
    [PCRecentSta3n_ICN]                  SMALLINT        NULL,
    [OtherRecentVisitDate_ICN]           DATETIME2 (0)   NULL,
    [OtherRecentStopCode_ICN]            VARCHAR (5)     NULL,
    [OtherRecentStopCodeName_ICN]        VARCHAR (100)   NULL,
    [OtherRecentSta3n_ICN]               SMALLINT        NULL,
    [Admitted]                           INT             NOT NULL
);


















GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PatientReport]
    ON [REACH].[PatientReport];

