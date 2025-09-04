CREATE TABLE [Config].[ErrorNotice_v02] (
    [ErrorDate]                    SMALLDATETIME  NOT NULL,
    [CloseDate]                    SMALLDATETIME  NULL,
    [ErrorDescription]             VARCHAR (1000) NULL,
    [PDSI_FacilitySummary]         BIT            NOT NULL,
    [PDSI_ProviderSummary]         BIT            NOT NULL,
    [PDSI_PatientDetail]           BIT            NOT NULL,
    [PDSI_PatientDetailQuickView]  BIT            NOT NULL,
    [MH008]                        BIT            NOT NULL,
    [Antidepressant]               BIT            NOT NULL,
    [AcademicDetailing]            BIT            NOT NULL,
    [Lithium]                      BIT            NOT NULL,
    [Delirium]                     BIT            NOT NULL,
    [STORM_Summary]                BIT            NOT NULL,
    [STORM_PatientDetail]          BIT            NOT NULL,
    [STORM_PatientDetailQuickView] BIT            NOT NULL,
    [STORM_PatientLookup]          BIT            NOT NULL,
    [HRF]                          BIT            NOT NULL,
    [HRF_NoteTitle]                BIT            NOT NULL,
    [REACH_Summary]                BIT            NOT NULL,
    [REACH_PatientDetail]          BIT            NOT NULL,
    [REACH_MasterList]             BIT            NOT NULL,
    [PDE]                          BIT            NOT NULL,
    [CRISTAL]                      BIT            NOT NULL,
    [EBP_Clinician]                BIT            NOT NULL,
    [EBP_Summary]                  BIT            NOT NULL,
    [SPPRITE]                      BIT            NOT NULL,
    [Test]                         BIT            NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ErrorNotice_v02]
    ON [Config].[ErrorNotice_v02];

