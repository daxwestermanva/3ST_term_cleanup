CREATE TABLE [OMHSP_Standard].[MentalHealthAssistant_v02] (
    [MVIPersonSID]            INT           NOT NULL,
    [PatientICN]              VARCHAR (50)  NOT NULL,
    [PatientPersonSID]        INT           NOT NULL,
    [Sta3n]                   SMALLINT      NULL,
    [ChecklistID]             NVARCHAR (5)  NULL,
    [LocationSID]             INT           NULL,
    [LocationSIDType]         VARCHAR (30)  NULL,
    [SurveyAdministrationSID] BIGINT        NULL,
    [SurveySIDType]           VARCHAR (30)  NULL,
    [SurveyGivenDatetime]     SMALLDATETIME NULL,
    [SurveyName]              VARCHAR (75)  NULL,
    [RawScore]                INT           NULL,
    [display_I9]              SMALLINT      NULL,
    [display_CSSRS]           SMALLINT      NULL,
    [display_AUDC]            SMALLINT      NULL,
    [display_PHQ2]            SMALLINT      NULL,
    [display_PHQ9]            SMALLINT      NULL,
    [display_COWS]            SMALLINT      NULL,
    [display_CIWA]            SMALLINT      NULL,
    [display_PTSD]            SMALLINT      NULL,
    [DisplayScore]            VARCHAR (30)  NULL
);













GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MentalHealthAssistant_v02]
    ON [OMHSP_Standard].[MentalHealthAssistant_v02];












GO


