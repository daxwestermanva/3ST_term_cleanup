CREATE TABLE [Present].[SStaff] (
    [StaffSSN]        VARCHAR (50)  NULL,
    [NetworkUsername] VARCHAR (100) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SStaff]
    ON [Present].[SStaff];

