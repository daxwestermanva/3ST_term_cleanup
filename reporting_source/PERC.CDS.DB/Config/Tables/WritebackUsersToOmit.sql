CREATE TABLE [Config].[WritebackUsersToOmit] (
    [UserName] VARCHAR (50) NULL
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_WritebackUsersToOmit]
    ON [Config].[WritebackUsersToOmit];

