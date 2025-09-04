CREATE TABLE [LookUp].[Sta6aCumulative] (
    [FYID]           INT            NULL,
    [VISN]           INT            NULL,
    [STA3N]          INT            NULL,
    [CurSTA3N]       INT            NULL,
    [Sta6a]          NVARCHAR (15)  NOT NULL,
    [ChecklistID]    NVARCHAR (10)  NULL,
    [STA6AID]        NVARCHAR (30)  NULL,
    [Nepec3n]        NVARCHAR (7)   NULL,
    [StaPa]          NVARCHAR (10)  NULL,
    [ADMParent_Key]  INT            NULL,
    [ADMPARENT_FCDM] NVARCHAR (100) NULL,
    [DIVISION_FCDM]  NVARCHAR (150) NULL,
    [FacilityLevel]  VARCHAR (50)   NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Sta6aCumulative]
    ON [LookUp].[Sta6aCumulative];

