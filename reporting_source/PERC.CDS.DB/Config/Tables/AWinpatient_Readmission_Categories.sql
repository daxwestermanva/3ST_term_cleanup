CREATE TABLE [Config].[AWinpatient_Readmission_Categories] (
    [AHRQ_CCS_Procedure_Category] INT           NULL,
    [CCS_Label]                   VARCHAR (500) NULL,
    [PlannedType]                 VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AWinpatient_Readmission_Categories]
    ON [Config].[AWinpatient_Readmission_Categories];

