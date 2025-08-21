CREATE TABLE [LookUp].[MaritalStatus] (
    [MaritalStatusSID]             BIGINT        NOT NULL,
    [Sta3n]                        SMALLINT      NOT NULL,
    [MaritalStatus]                VARCHAR (100) NULL,
    [Reach_Widow_MaritalStatus]    SMALLINT      NULL,
    [Reach_Divorced_MaritalStatus] SMALLINT      NULL,
    [Reach_Married_MaritalStatus]  SMALLINT      NULL
);


GO
CREATE UNIQUE CLUSTERED INDEX [pk_CrosswalkMaritalStatus__MaritalStatusSID]
    ON [LookUp].[MaritalStatus]([MaritalStatusSID] ASC) WITH (DATA_COMPRESSION = PAGE);


GO
