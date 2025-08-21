CREATE TABLE [ORM].[MetricTable] (
    [VISN]                INT              NULL,
    [ChecklistID]         NVARCHAR (30)    NULL,
    [ADMParent_FCDM]      NVARCHAR (510)   NULL,
    [GroupID]             INT              NULL,
    [GroupType]           VARCHAR (25)     NULL,
    [ProviderSID]         INT              NULL,
    [ProviderName]        VARCHAR (100)    NULL,
    [Riskcategory]        INT              NULL,
    [AllOpioidPatient]    INT              NULL,
    [AllOpioidRXPatient]  INT              NULL,
    [AllOUDPatient]       INT              NULL,
    [AllOpioidSUDPatient] INT              NULL,
    [MeasureID]           NVARCHAR (128)   NULL,
    [PrintName]           VARCHAR (500)    NULL,
    [Permeasure]          NVARCHAR (128)   NULL,
    [Numerator]           INT              NOT NULL,
    [Denominator]         INT              NULL,
    [Score]               DECIMAL (25, 14) NULL,
    [NatScore]            DECIMAL (25, 14) NULL,
    [AllTxPatients]       INT              NULL,
    [AllPastYearODCount]  INT              NULL
);










GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MetricTable]
    ON [ORM].[MetricTable];

