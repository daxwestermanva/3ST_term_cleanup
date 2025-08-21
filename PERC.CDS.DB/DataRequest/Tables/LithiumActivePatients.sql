CREATE TABLE [DataRequest].[LithiumActivePatients] (
    [sta3n]               SMALLINT      NOT NULL,
    [Patientsid]          INT           NULL,
    [patienticn]          VARCHAR (50)  NULL,
    [drugnamewithoutdose] VARCHAR (100) NULL,
    [MonthsInTreatment]   INT           NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_LithiumActivePatients]
    ON [DataRequest].[LithiumActivePatients];

