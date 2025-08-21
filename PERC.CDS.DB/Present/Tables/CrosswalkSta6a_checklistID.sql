CREATE TABLE [Present].[CrosswalkSta6a_checklistID] (
    [VISN]           INT            NULL,
    [STA3N]          INT            NULL,
    [Sta6a]          NVARCHAR (30)  NOT NULL,
    [ChecklistID]    NVARCHAR (30)  NULL,
    [Sta6aid]        NVARCHAR (7)   NULL,
    [ADMParent_Key]  INT            NULL,
    [ADMPARENT_FCDM] NVARCHAR (510) NULL,
    [DIVISION_FCDM]  NVARCHAR (712) NULL,
    [FacilityLevel]  VARCHAR (100)  NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CrosswalkSta6a_checklistID]
    ON [Present].[CrosswalkSta6a_checklistID];

