CREATE TABLE [OracleH_QI].[PossibleMHVisits] (
    [MVIPersonSID]        INT           NOT NULL,
    [StaPa]               VARCHAR (5)   NULL,
    [Inpatient]           TINYINT       NULL,
    [EncounterSID]        BIGINT        NULL,
    [TZServiceDateTime]   SMALLDATETIME NULL,
    [ActivityType]        VARCHAR (100) NULL,
    [StopCode]            VARCHAR (10)  NULL,
    [EncounterType]       VARCHAR (100) NULL,
    [MedService]          VARCHAR (100) NULL,
    [PersonStaffSID]      BIGINT        NULL,
    [PatientLocation]     VARCHAR (100) NULL,
    [StaffName]           VARCHAR (100) NULL,
    [CPTCode]             VARCHAR (50)  NULL,
    [ChargeDescription]   VARCHAR (200) NULL,
    [HRF]                 TINYINT       NULL,
    [PDE]                 TINYINT       NULL,
    [NonMHActivityType]   TINYINT       NULL,
    [IncompleteEncounter] TINYINT       NULL,
    [NoCharge]            TINYINT       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PossibleMHVisits]
    ON [OracleH_QI].[PossibleMHVisits];

