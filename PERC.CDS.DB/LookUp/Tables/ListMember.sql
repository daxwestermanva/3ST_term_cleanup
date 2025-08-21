CREATE TABLE [LookUp].[ListMember] (
    [List]             VARCHAR (50)  NOT NULL,
    [Domain]           VARCHAR (50)  NOT NULL,
    [Attribute]        VARCHAR (50)  NOT NULL,
    [ItemID]           INT           NOT NULL,
    [ItemIDName]       VARCHAR (50)  NULL,
    [AttributeValue]   VARCHAR (500) NULL,
    [CreatedDateTime]  SMALLDATETIME CONSTRAINT [DF_ListMember_CreatedDateTime] DEFAULT (getdate()) NOT NULL,
    [MappingSource]    VARCHAR (50)  NULL,
    [ApprovalStatus]   VARCHAR (50)  NULL,
    [ApprovedDateTime] SMALLDATETIME NULL,
    CONSTRAINT [UK_LookUp_ListMember] UNIQUE NONCLUSTERED ([List] ASC, [Domain] ASC, [ItemID] ASC, [AttributeValue] ASC)
);




GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ListMember]
    ON [LookUp].[ListMember];

