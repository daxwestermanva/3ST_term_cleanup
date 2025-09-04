SELECT Instance_ID, Class, SUBCLASS, Preferred_Label, SUBCLASS_GROUPING
FROM Config.NLP_3ST_subclass_labels WITH (NOLOCK)
WHERE Polarity='indicates_presence'
    AND (Class='Psychological Pain'
        AND Subclass IN ('Pain exceeds tolerance','Housing issues','Sleep issues','Financial issues','Legal issues')
    OR (Class='Capacity for Suicide'))