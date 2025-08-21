CREATE TABLE [CaringLetters].[VCL_PreEmptiveOptOuts] (
    [DateAdded] DATE         NULL,
    [Report_ID] VARCHAR (50) NULL,
    [LastName]  VARCHAR (50) NULL,
    [FirstName] VARCHAR (50) NULL,
    [SSN]       VARCHAR (15) NULL,
    [vcl_ID]    VARCHAR (50) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_CaringLetters_PreEmptiveOptOuts]
    ON [CaringLetters].[VCL_PreEmptiveOptOuts];

