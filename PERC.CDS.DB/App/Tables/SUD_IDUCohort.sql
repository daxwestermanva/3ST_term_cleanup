CREATE TABLE [App].[SUD_IDUCohort] (
    [CheckListID]  NVARCHAR (10) NULL,
    [MVIPersonSID] INT           NULL,
    [Confirmed]    INT           NOT NULL,
    [InSSP]        VARCHAR (13)  NOT NULL,
    [PatientName]  VARCHAR (200) NULL,
    [LastFour]     CHAR (4)      NULL,
    [DateOfBirth]  DATE          NULL,
    [SUDDx]        VARCHAR (9)   NOT NULL,
    [Prep]         VARCHAR (3)   NOT NULL,
    [Naloxone]     VARCHAR (3)   NOT NULL,
    [Condom]       VARCHAR (3)   NOT NULL,
    [FentanylTS]   VARCHAR (3)   NOT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SUD_IDUCohort]
    ON [App].[SUD_IDUCohort];

