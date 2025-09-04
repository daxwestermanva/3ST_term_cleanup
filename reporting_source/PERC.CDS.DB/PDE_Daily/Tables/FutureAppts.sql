CREATE TABLE [PDE_Daily].[FutureAppts] (
    [MVIPersonSID]        INT            NOT NULL,
    [DisDay]              DATE           NULL,
    [AppointmentSID]      BIGINT         NOT NULL,
    [AppointmentDateTime] DATETIME2 (0)  NULL,
    [AppointmentDate]     DATE           NULL,
    [LocationName]        VARCHAR (100)  NULL,
    [ApptFacility]        NVARCHAR (100) NULL,
    [ApptDivision]        VARCHAR (100)  NULL,
    [PrimaryStopCode]     VARCHAR (10)   NULL,
    [P_StopCodeName]      NVARCHAR (MAX) NULL,
    [SecondaryStopCode]   VARCHAR (10)   NULL,
    [S_StopCodeName]      VARCHAR (100)  NULL,
    [RowNum]              BIGINT         NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_FutureAppts]
    ON [PDE_Daily].[FutureAppts];

