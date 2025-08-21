CREATE TABLE [ORM].[OPPEMetric] (
    [VISN]           INT              NOT NULL,
    [ChecklistID]    NVARCHAR (30)    NULL,
    [ADMParent_FCDM] NVARCHAR (100)   NULL,
    [GroupID]        INT              NOT NULL,
    [GroupType]      VARCHAR (25)     NOT NULL,
    [ProviderSID]    INT              NOT NULL,
    [ProviderName]   VARCHAR (100)    NOT NULL,
    [AllLTOTCount]   INT              NULL,
    [MeasureID]      FLOAT (53)       NULL,
    [Permeasure]     VARCHAR (40)     NULL,
    [PrintName]      VARCHAR (500)    NULL,
    [Numerator]      INT              NULL,
    [Denominator]    INT              NULL,
    [Score]          DECIMAL (29, 19) NULL,
    [DueNinetyDays]  INT              NULL,
    [NatScore]       DECIMAL (29, 19) NULL,
    [AllTxPatients]  INT              NULL,
    [MetricDate]     DATETIME         NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_OPPEMetric]
    ON [ORM].[OPPEMetric];

