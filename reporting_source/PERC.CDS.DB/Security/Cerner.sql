CREATE SCHEMA [Cerner]
    AUTHORIZATION [uOMHSP_PERC];








GO
EXECUTE sp_addextendedproperty @name = N'SchemaDescription', @value = N'Objects based on Cerner data that are curated in the OMHSP_PERC_Cerner database system.', @level0type = N'SCHEMA', @level0name = N'Cerner';

