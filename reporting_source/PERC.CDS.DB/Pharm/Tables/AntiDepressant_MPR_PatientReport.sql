CREATE TABLE [Pharm].[AntiDepressant_MPR_PatientReport] (
    [PatientSID]                  INT              NOT NULL,
    [MeasureType]                 VARCHAR (6)      NULL,
    [LastFillBeforeIndex]         DATETIME2 (0)    NULL,
    [IndexDate]                   DATETIME2 (0)    NULL,
    [DaysSinceIndex]              INT              NULL,
    [MeasureEndDate]              DATETIME2 (0)    NULL,
    [TotalDaysSupply]             INT              NULL,
    [PassedMeasure]               INT              NOT NULL,
    [DrugNameWithoutDose]         VARCHAR (100)    NULL,
    [RefillRequired]              VARCHAR (15)     NULL,
    [Prescriber]                  VARCHAR (100)    NULL,
    [PrescriberSID]               INT              NULL,
    [LastRelease]                 DATETIME2 (0)    NULL,
    [DaysSinceLastFill]           INT              NULL,
    [RxType]                      VARCHAR (3)      NULL,
    [LastDaysSupply]              INT              NULL,
    [MPRToday]                    NUMERIC (37, 19) NULL,
    [PCFutureAppointmentDateTime] DATETIME2 (0)    NULL,
    [PCFutureStopCodeName]        VARCHAR (100)    NULL,
    [MHRecentVisitDate]           DATETIME2 (0)    NULL,
    [MHRecentStopCodeName]        VARCHAR (100)    NULL,
    [PCRecentVisitDate]           DATETIME2 (0)    NULL,
    [PCRecentStopCodeName]        VARCHAR (100)    NULL,
    [MHFutureAppointmentDateTime] DATETIME2 (0)    NULL,
    [MHFutureStopCodeName]        VARCHAR (100)    NULL,
    [RxStatus]                    VARCHAR (50)     NULL,
    [prescribername_type]         VARCHAR (106)    NULL,
    [PrescriberType]              VARCHAR (11)     NULL,
    [ChecklistID]                 VARCHAR (5)      NULL,
    [MVIPersonSID]                INT              NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AntiDepressant_MPR_PatientReport]
    ON [Pharm].[AntiDepressant_MPR_PatientReport];

