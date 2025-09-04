CREATE TABLE [BHIP].[MHTC_FollowUpDetails] (
    [CHECKLISTID]          NVARCHAR (30)  NULL,
    [MVIPERSONSID]         INT            NOT NULL,
    [PATIENTICN]           VARCHAR (50)   NULL,
    [VISITDATETIME]        DATETIME2 (0)  NULL,
    [VISITSID]             BIGINT         NULL,
    [HEALTHFACTORSID]      BIGINT         NULL,
    [HealthFactorType]     VARCHAR (250)  NULL,
    [HF_CATEGORY]          VARCHAR (8)    NOT NULL,
    [PrintName]            VARCHAR (100)  NULL,
    [HEALTHFACTORDATETIME] DATETIME2 (0)  NULL,
    [COMMENTS]             VARCHAR (8000) NULL,
    [HF_KEY]               NVARCHAR (122) NOT NULL,
    [list]                 VARCHAR (50)   NOT NULL
);




GO
CREATE CLUSTERED INDEX [ClusteredIndex-20250617-162729]
    ON [BHIP].[MHTC_FollowUpDetails]([CHECKLISTID] ASC, [MVIPERSONSID] ASC);

