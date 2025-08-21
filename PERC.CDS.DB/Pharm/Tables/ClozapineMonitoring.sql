CREATE TABLE [Pharm].[ClozapineMonitoring] (
    [ChecklistID]                         NVARCHAR (30)   NULL,
    [MVIPersonSID]                        INT             NOT NULL,
    [DrugNameWithoutDose]                 VARCHAR (100)   NULL,
    [Inpatient]                           INT             NOT NULL,
    [OutPat_Rx]                           INT             NOT NULL,
    [CPRS_Order]                          INT             NOT NULL,
    [max_releasedatetime]                 DATETIME2 (0)   NULL,
    [DaysSupply]                          INT             NULL,
    [PillsOnHand]                         VARCHAR (16)    NULL,
    [DateSinceLastPillsHand]              DATETIME2 (0)   NULL,
    [MostRecentANC_D&T]                   DATETIME2 (0)   NULL,
    [ANC_Value]                           DECIMAL (18, 2) NULL,
    [ANC_Units]                           VARCHAR (103)   NULL,
    [Calc_value_used]                     VARCHAR (1)     NOT NULL,
    [<30d_LowestPrev_LabChemSpecDateTime] DATETIME2 (0)   NULL,
    [<30d_LowestPrev_ANC_Value]           DECIMAL (18, 2) NULL,
    [Previous_ANC_Units]                  VARCHAR (103)   NULL,
    [Prev_Calc_value_used]                VARCHAR (1)     NOT NULL,
    [MostRecentClozapine_D&T]             DATETIME2 (0)   NULL,
    [Clozapine_Lvl]                       VARCHAR (100)   NULL,
    [Cloz_Units]                          VARCHAR (103)   NULL,
    [MostRecentNorclozapine_D&T]          DATETIME2 (0)   NULL,
    [Norclozapine_Lvl]                    VARCHAR (100)   NULL,
    [Nor_Units]                           VARCHAR (103)   NULL,
    [VisitDateTime]                       DATETIME2 (0)   NULL,
    [NPI]                                 VARCHAR (50)    NULL,
    [Prescriber]                          VARCHAR (100)   NULL,
    [Visit_Location]                      VARCHAR (50)    NULL,
    [VisitStaff]                          VARCHAR (50)    NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ClozapineMonitoring]
    ON [Pharm].[ClozapineMonitoring];

