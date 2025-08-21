CREATE TABLE [PDSI].[CM_Status] (
    [ChecklistID]      NVARCHAR (255) NULL,
    [STA6AID]          NVARCHAR (255) NULL,
    [VISN]             INT            NULL,
    [Modified]         DATETIME       NULL,
    [CM_Prog_Status]   BIT            NULL,
    [CM_Active_Status] BIT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CM_Status]
    ON [PDSI].[CM_Status];

