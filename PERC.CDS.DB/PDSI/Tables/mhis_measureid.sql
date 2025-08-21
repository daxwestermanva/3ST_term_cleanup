CREATE TABLE [PDSI].[mhis_measureid] (
    [PROGRAM_ID]               FLOAT (53)     NULL,
    [MEASUREID]                FLOAT (53)     NULL,
    [MEASUREMNEMONIC]          NVARCHAR (255) NULL,
    [MEASURENAME]              NVARCHAR (255) NULL,
    [MeasureShortDescription]  NVARCHAR (MAX) NULL,
    [MeasureLongDescription]   NVARCHAR (MAX) NULL,
    [DATASOURCEDEFINITION]     NVARCHAR (255) NULL,
    [STARTDATE]                DATETIME       NULL,
    [ENDDATE]                  NVARCHAR (255) NULL,
    [MEASURESTATUSID]          NVARCHAR (255) NULL,
    [MEASURECLASSIFICATIONID]  NVARCHAR (255) NULL,
    [PARENTCOMPOSITEMEASUREID] NVARCHAR (255) NULL,
    [REPLACEDBYMEASUREID]      NVARCHAR (255) NULL,
    [SponsorID]                NVARCHAR (255) NULL,
    [SOURCEREPORTURLID]        NVARCHAR (255) NULL,
    [MEASURENOTES]             NVARCHAR (255) NULL,
    [Threshold_directionality] NVARCHAR (255) NULL,
    [POLICY_THRESHOLD]         NVARCHAR (255) NULL,
    [High_threshold]           NVARCHAR (255) NULL,
    [low_threshold]            FLOAT (53)     NULL,
    [current_threshold]        FLOAT (53)     NULL,
    [CURRENT_METNOTMET]        NVARCHAR (255) NULL,
    [dataformat]               NVARCHAR (255) NULL,
    [SUBELEMENTID]             NVARCHAR (255) NULL,
    [SUBELEMENTNAME]           NVARCHAR (255) NULL,
    [METRICORDERID]            NVARCHAR (255) NULL,
    [HELPURL]                  NVARCHAR (255) NULL,
    [REPORTURL]                NVARCHAR (255) NULL,
    [MEASUREKEY]               NVARCHAR (255) NULL,
    [DATADEFURL]               NVARCHAR (255) NULL,
    [drill]                    INT            NULL
)
WITH (DATA_COMPRESSION = PAGE);


GO
