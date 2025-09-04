CREATE TABLE [DeltaView].[SStaffSID_POCTestOnly] (
    [StaffSID]        INT           NULL,
    [StaffSSN]        VARCHAR (50)  NULL,
    [NetworkUsername] VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DeltaView_SStaffSID]
    ON [DeltaView].[SStaffSID_POCTestOnly];

