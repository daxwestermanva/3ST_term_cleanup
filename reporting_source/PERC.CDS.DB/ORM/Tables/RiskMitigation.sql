CREATE TABLE [ORM].[RiskMitigation] (
    [MVIPersonSID]    INT           NULL,
    [PrintName]       VARCHAR (100) NULL,
    [MitigationID]    SMALLINT      NOT NULL,
    [DetailsText]     VARCHAR (60)  NULL,
    [DetailsDate]     DATETIME2 (7) NULL,
    [Checked]         SMALLINT      NOT NULL,
    [Red]             BIT           NOT NULL,
    [MetricInclusion] BIT           NULL,
    [MitigationIDRx]  FLOAT (53)    NULL,
    [PrintNameRx]     VARCHAR (100) NULL,
    [CheckedRx]       INT           NOT NULL,
    [RedRx]           INT           NOT NULL
);








GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_RiskMitigation]
    ON [ORM].[RiskMitigation];

