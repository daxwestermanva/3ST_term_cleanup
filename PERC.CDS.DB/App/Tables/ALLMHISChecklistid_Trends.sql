CREATE TABLE [App].[ALLMHISChecklistid_Trends] (
    [pec]               VARCHAR (7)    NOT NULL,
    [program_id]        INT            NULL,
    [measureid]         INT            NULL,
    [yearid]            INT            NULL,
    [timeframeid]       INT            NULL,
    [reportingperiodid] INT            NULL,
    [loaddate]          VARCHAR (10)   NULL,
    [passfail]          VARCHAR (10)   NULL,
    [sta6aid]           NVARCHAR (30)  NOT NULL,
    [ChecklistID]       NVARCHAR (30)  NOT NULL,
    [NEPEC3n]           INT            NULL,
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
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ALLMHISChecklistid_Trends]
    ON [App].[ALLMHISChecklistid_Trends];

