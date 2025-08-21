CREATE TABLE [PDSI].[mhis_all_pecs_data] (
    [pec]               VARCHAR (7)    NOT NULL,
    [program_id]        INT            NULL,
    [measureid]         INT            NULL,
    [yearid]            INT            NULL,
    [timeframeid]       INT            NULL,
    [reportingperiodid] INT            NULL,
    [loaddate]          VARCHAR (10)   NULL,
    [passfail]          VARCHAR (10)   NULL,
    [sta6aid]           NVARCHAR (30)  NOT NULL,
    [checklistid]       NVARCHAR (30)  NOT NULL,
    [Nepec3n]           INT            NULL,
    [visn]              INT            NULL,
    [admparent_key]     INT            NULL,
    [cursta3n]          INT            NULL,
    [admparent_fcdm]    NVARCHAR (255) NULL,
    [best_met_notmet]   VARCHAR (10)   NULL,
    [low_met_notmet]    VARCHAR (10)   NULL,
    [score]             VARCHAR (15)   NULL,
    [numerator]         VARCHAR (15)   NULL,
    [denominator]       VARCHAR (15)   NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_mhis_all_pecs_data]
    ON [PDSI].[mhis_all_pecs_data];

