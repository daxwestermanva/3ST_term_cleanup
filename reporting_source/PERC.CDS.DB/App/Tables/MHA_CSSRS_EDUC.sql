CREATE TABLE [App].[MHA_CSSRS_EDUC] (
    [MVIPersonSID]        INT           NOT NULL,
    [PatientICN]          VARCHAR (50)  NOT NULL,
    [PatientPersonSID]    INT           NOT NULL,
    [Sta3n]               SMALLINT      NULL,
    [ChecklistID]         NVARCHAR (5)  NULL,
    [LocationSID]         INT           NULL,
    [SurveyGivenDatetime] SMALLDATETIME NULL,
    [SurveyName]          VARCHAR (75)  NULL,
    [display_CSSRS]       SMALLINT      NOT NULL,
    [EDSC]                BIT           NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MHA_CSSRS_EDUC]
    ON [App].[MHA_CSSRS_EDUC];

