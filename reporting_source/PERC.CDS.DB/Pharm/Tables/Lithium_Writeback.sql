CREATE TABLE [Pharm].[Lithium_Writeback] (
    [sta3n]           SMALLINT       NULL,
    [PatientICN]      INT            NULL,
    [PatientReviewed] INT            NULL,
    [ExecutionDate]   DATETIME       NULL,
    [UserID]          VARCHAR (MAX)  NULL,
    [LabsNotShowing]  NVARCHAR (255) NULL,
    [PlanToAddress]   NVARCHAR (MAX) NULL
);

