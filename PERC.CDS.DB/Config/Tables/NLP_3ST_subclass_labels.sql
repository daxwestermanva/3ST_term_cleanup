CREATE TABLE [Config].[NLP_3ST_subclass_labels] (
    [INSTANCE_ID]            INT           NULL,
    [POLARITY]               VARCHAR (50)  NULL,
    [CLASS]                  VARCHAR (50)  NULL,
    [SUBCLASS]               VARCHAR (100) NULL,
    [RELATIONSHIP]           VARCHAR (100) NULL,
    [ONTOLOGY]               VARCHAR (5)   NULL,
    [RESTRICTED_INSTANCE_ID] INT           NULL,
    [PREFERRED_LABEL]        VARCHAR (200) NULL,
    [SUBCLASS_GROUPING]      VARCHAR (250) NULL
);

