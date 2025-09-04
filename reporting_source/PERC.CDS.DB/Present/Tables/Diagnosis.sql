CREATE TABLE [Present].[Diagnosis] (
    [MVIPersonSID] INT          NOT NULL,
    [DxCategory]   VARCHAR (50) NULL,
    [SourceEHR]    VARCHAR (3)  NULL,
    [Outpat]       BIT          NULL,
    [Inpat]        BIT          NULL,
    [DoD]          BIT          NULL,
    [CommCare]     BIT          NULL,
    [PL]           BIT          NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Diagnosis]
    ON [Present].[Diagnosis];

