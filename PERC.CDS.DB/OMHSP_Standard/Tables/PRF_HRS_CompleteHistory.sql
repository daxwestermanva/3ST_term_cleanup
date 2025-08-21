CREATE TABLE [OMHSP_Standard].[PRF_HRS_CompleteHistory] (
    [MVIPersonSID]          INT            NOT NULL,
    [PatientICN]            VARCHAR (50)   NOT NULL,
    [OwnerChecklistID]      VARCHAR (5)    NULL,
    [OwnerFacility]         NVARCHAR (510) NULL,
    [ActiveFlag]            VARCHAR (1)    NULL,
    [InitialActivation]     DATETIME2 (0)  NULL,
    [MostRecentActivation]  DATETIME2 (0)  NULL,
    [ActionDateTime]        DATETIME2 (0)  NOT NULL,
    [ActionType]            TINYINT        NULL,
    [ActionTypeDescription] VARCHAR (32)   NULL,
    [HistoricStatus]        VARCHAR (1)    NULL,
    [EntryCountDesc]        INT            NULL,
    [EntryCountAsc]         INT            NULL,
    [PastWeekActivity]      TINYINT        NULL,
    [NextReviewDate]        DATE           NULL,
    [MinReviewDate]         DATE           NULL,
    [MaxReviewDate]         DATE           NULL
);








GO
CREATE CLUSTERED COLUMNSTORE INDEX [ccix_SPGS_PRFHRSCompleteHistory]
    ON [OMHSP_Standard].[PRF_HRS_CompleteHistory];





