CREATE TABLE [LookUp].[ChecklistidCumulative] (
    [FYID]            SMALLINT       NOT NULL,
    [ChecklistID]     NVARCHAR (10)  NOT NULL,
    [STA6AID]         NVARCHAR (10)  NOT NULL,
    [VISN_FCDM]       NVARCHAR (20)  NOT NULL,
    [VISN]            INT            NULL,
    [ADMPARENT_FCDM]  NVARCHAR (100) NOT NULL,
    [ADMParent_Key]   INT            NOT NULL,
    [CurSTA3N]        INT            NOT NULL,
    [District]        INT            NULL,
    [STA3N]           INT            NOT NULL,
    [FacilityID]      INT            NOT NULL,
    [FacilityLevel]   VARCHAR (50)   NOT NULL,
    [FacilityLevelID] SMALLINT       NOT NULL,
    [Nepec3n]         NVARCHAR (7)   NOT NULL,
    [Facility]        NVARCHAR (100) NULL,
    [MCGKey]          INT            NULL,
    [MCGName]         VARCHAR (50)   NULL,
    [StaPa]           NVARCHAR (10)  NULL,
    [ADMPSortKey]     BIGINT         NULL
);








GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ChecklistidCumulative]
    ON [LookUp].[ChecklistidCumulative];

