CREATE TABLE [Present].[SStaffSID] (
    [StaffSID]        INT           NULL,
    [StaffSSN]        VARCHAR (50)  NULL,
    [NetworkUsername] VARCHAR (100) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_SStaffSID]
    ON [Present].[SStaffSID];

