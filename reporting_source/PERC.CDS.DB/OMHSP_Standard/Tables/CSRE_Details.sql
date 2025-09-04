CREATE TABLE [OMHSP_Standard].[CSRE_Details] (
    [MVIPersonSID]       INT           NOT NULL,
    [PatientICN]         VARCHAR (50)  NULL,
    [Sta3n]              SMALLINT      NULL,
    [ChecklistID]        NVARCHAR (30) NULL,
    [VisitSID]           BIGINT        NULL,
    [DocFormActivitySID] BIGINT        NULL,
    [EntryDateTime]      SMALLDATETIME NULL,
    [Type]               VARCHAR (25)  NULL,
    [PrintName]          VARCHAR (100) NULL,
    [Comments]           VARCHAR (255) NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CSRE_Details]
    ON [OMHSP_Standard].[CSRE_Details];

