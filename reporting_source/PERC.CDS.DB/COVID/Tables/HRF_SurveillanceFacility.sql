CREATE TABLE [COVID].[HRF_SurveillanceFacility] (
    [VISN]        INT            NULL,
    [ChecklistID] VARCHAR (5)    NULL,
    [MeasureName] VARCHAR (16)   NULL,
    [Denominator] SMALLINT       NULL,
    [Numerator]   SMALLINT       NULL,
    [Score]       DECIMAL (8, 5) NULL,
    [MonthEnd]    DATE           NULL,
    [RunDate]     DATE           NULL,
    [MeasureType] CHAR (1)       NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HRF_SurveillanceFacility]
    ON [COVID].[HRF_SurveillanceFacility];

