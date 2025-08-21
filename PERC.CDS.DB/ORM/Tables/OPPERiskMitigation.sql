CREATE TABLE [ORM].[OPPERiskMitigation] (
    [MVIPersonSID]    INT           NULL,
    [MitigationID]    FLOAT (53)    NULL,
    [PrintName]       VARCHAR (538) NULL,
    [DetailsDate]     DATE          NULL,
    [Checked]         INT           NOT NULL,
    [Red]             INT           NOT NULL,
    [MetricInclusion] INT           NOT NULL,
    [DueNinetyDays]   INT           NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_OPPERiskMitigation]
    ON [ORM].[OPPERiskMitigation];

