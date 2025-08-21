CREATE TABLE [PDSI].[PatientDetails] (
    [MVIPersonSID]             INT            NULL,
    [Locations]                VARCHAR (5)    NULL,
    [LocationName]             NVARCHAR (255) NULL,
    [LocationsColor]           NVARCHAR (255) NULL,
    [MeasureID]                FLOAT (53)     NOT NULL,
    [Measure]                  NVARCHAR (255) NULL,
    [DetailsText]              NVARCHAR (255) NULL,
    [DetailsDate]              DATETIME2 (0)  NULL,
    [MeasureUnmet]             INT            NULL,
    [PTSD]                     INT            NULL,
    [SUD]                      INT            NULL,
    [MOUD_Key]                 INT            NULL,
    [ALC_Top_Key]              INT            NULL,
    [PDMP]                     INT            NULL,
    [NaloxoneKit]              INT            NULL,
    [UDS]                      INT            NULL,
    [Age65_Eligible]           INT            NULL,
    [OpioidForPain_Rx]         BIT            NULL,
    [Benzodiazepine5]          INT            NULL,
    [Benzodiazepine5_Schedule] INT            NULL,
    [DxId]                     BIGINT         NOT NULL,
    [Diagnosis]                VARCHAR (1000) NULL,
    [DxCategory]               VARCHAR (25)   NULL,
    [Category]                 VARCHAR (100)  NULL,
    [MedID]                    BIGINT         NOT NULL,
    [DrugName]                 NVARCHAR (MAX) NULL,
    [PrescriberName]           NVARCHAR (MAX) NULL,
    [MedType]                  VARCHAR (30)   NULL,
    [MedLocation]              NVARCHAR (30)  NULL,
    [MedLocationName]          NVARCHAR (255) NULL,
    [MedLocationColor]         NVARCHAR (255) NULL,
    [MonthsinTreatment]        FLOAT (53)     NULL,
    [GroupID]                  INT            NULL,
    [GroupType]                VARCHAR (21)   NULL,
    [ProviderName]             VARCHAR (100)  NULL,
    [ProviderSID]              INT            NULL,
    [ProviderLocation]         NVARCHAR (30)  NULL,
    [ProviderLocationName]     NVARCHAR (255) NULL,
    [ProviderLocationColor]    NVARCHAR (255) NULL,
    [AppointmentID]            BIGINT         NOT NULL,
    [AppointmentType]          VARCHAR (24)   NULL,
    [AppointmentStop]          VARCHAR (50)   NULL,
    [AppointmentDateTime]      DATETIME2 (0)  NULL,
    [AppointmentLocation]      VARCHAR (5)    NULL,
    [AppointmentLocationName]  NVARCHAR (255) NULL,
    [AppointmentLocationColor] NVARCHAR (255) NULL,
    [VisitStop]                VARCHAR (100)  NULL,
    [VisitDateTime]            DATETIME2 (0)  NULL,
    [VisitLocation]            VARCHAR (5)    NULL,
    [VisitLocationName]        NVARCHAR (255) NULL,
    [VisitLocationColor]       NVARCHAR (255) NULL,
    [AUDActiveMostRecent]      BIT            NULL,
    [OUDActiveMostRecent]      BIT            NULL,
    [OpioidForPain5]           BIT            NULL,
    [Sedative_zdrug5]          BIT            NULL,
    [CM]                       BIT            NULL,
    [CBTSUD]                   BIT            NULL,
    [Vitals]                   NVARCHAR (100) NULL,
    [ADD_ADHD]                 BIT            NULL,
    [Narcolepsy]               BIT            NULL,
    [BingeEating]              BIT            NULL,
    [LastCBTSUD]               DATETIME2 (0)  NULL,
    [MedIssueDate]             DATETIME2 (7)  NULL,
    [MedReleaseDate]           DATETIME2 (7)  NULL,
    [MedRxStatus]              VARCHAR (50)   NULL,
    [MedDrugStatus]            VARCHAR (50)   NULL,
    [StimulantADHD_rx]         BIT            NULL,
    [VitalsDate]               DATETIME2 (0)  NULL
);


























GO





GO


