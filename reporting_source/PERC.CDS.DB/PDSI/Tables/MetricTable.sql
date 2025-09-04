CREATE TABLE [PDSI].[MetricTable] (
    [VISN]             TINYINT          NULL,
    [ChecklistID]      VARCHAR (5)      NULL,
    [GroupID]          INT              NULL,
    [GroupType]        VARCHAR (25)     NULL,
    [ProviderSID]      INT              NULL,
    [ProviderName]     VARCHAR (100)    NULL,
    [MeasureID]        INT              NULL,
    [Measure]          VARCHAR (25)     NULL,
    [Denominator]      INT              NULL,
    [Numerator]        INT              NULL,
    [Score]            DECIMAL (21, 3)  NULL,
    [NatScore]         DECIMAL (25, 14) NULL,
    [Actionable]       INT              NULL,
    [CM_Numerator]     INT              NULL,
    [CBTSUD_Numerator] INT              NULL,
    [MeasureReviewed]  INT              NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MetricTable]
    ON [PDSI].[MetricTable];

