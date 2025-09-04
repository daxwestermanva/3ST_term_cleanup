CREATE TABLE [Present].[MHActiveStaff] (
    [staffsid] INT NOT NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MHActiveStaff]
    ON [Present].[MHActiveStaff];

