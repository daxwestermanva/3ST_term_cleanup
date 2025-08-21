CREATE TABLE [DeltaView].[SStaff_POCTestOnly] (
    [StaffSSN]        VARCHAR (50)  NULL,
    [NetworkUsername] VARCHAR (100) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DeltaView_SStaff]
    ON [DeltaView].[SStaff_POCTestOnly];

