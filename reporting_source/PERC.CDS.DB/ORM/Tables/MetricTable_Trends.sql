CREATE TABLE [ORM].[MetricTable_Trends] (
    [VISN]               INT              NULL,
    [ChecklistID]        NVARCHAR (30)    NULL,
    [GroupID]            INT              NULL,
    [ProviderSID]        INT              NULL,
    [Riskcategory]       INT              NULL,
    [AllOpioidPatient]   INT              NULL,
    [AllOpioidRXPatient] INT              NULL,
    [AllOUDPatient]      INT              NULL,
    [Measureid]          NVARCHAR (128)   NULL,
    [Numerator]          INT              NOT NULL,
    [Denominator]        INT              NULL,
    [Score]              DECIMAL (25, 14) NULL,
    [NatScore]           DECIMAL (25, 14) NULL,
    [AllTxPatients]      INT              NULL,
    [UpdateDate]         DATETIME         NOT NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MetricTable_Trends]
    ON [ORM].[MetricTable_Trends];

