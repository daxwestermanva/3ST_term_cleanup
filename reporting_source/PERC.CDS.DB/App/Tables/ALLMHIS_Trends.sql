CREATE TABLE [App].[ALLMHIS_Trends] (
    [pec]               VARCHAR (7)    NOT NULL,
    [program_id]        INT            NULL,
    [measureid]         INT            NULL,
    [yearid]            INT            NULL,
    [timeframeid]       INT            NULL,
    [reportingperiodid] INT            NULL,
    [loaddate]          VARCHAR (10)   NULL,
    [passfail]          VARCHAR (10)   NULL,
    [sta6aid]           NVARCHAR (15)  NULL,
    [visn]              INT            NULL,
    [admparent_key]     INT            NULL,
    [cursta3n]          INT            NULL,
    [admparent_fcdm]    NVARCHAR (255) NULL,
    [best_met_notmet]   VARCHAR (10)   NULL,
    [low_met_notmet]    VARCHAR (10)   NULL,
    [numerator]         VARCHAR (15)   NULL,
    [denominator]       VARCHAR (15)   NULL,
    [Measuremnemonic]   NVARCHAR (255) NULL,
    [Score]             VARCHAR (15)   NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ALLMHIS_Trends]
    ON [App].[ALLMHIS_Trends];

