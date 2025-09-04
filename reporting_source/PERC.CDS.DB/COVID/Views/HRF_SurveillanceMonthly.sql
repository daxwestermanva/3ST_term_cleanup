


CREATE VIEW [COVID].[HRF_SurveillanceMonthly]
AS

SELECT f.VISN
	  ,f.ChecklistID
	  ,c.ADMParent_FCDM
	  ,HRFC19_Elig				= max(Denominator)
	  ,HRFC19_EligOutAtt		= max(CASE WHEN MeasureName='OutAtt'		THEN Numerator	END)
	  ,OutAtt_Score				= max(CASE WHEN MeasureName='OutAtt'		THEN Score		END)
	  ,HRFC19_EligSucc			= max(CASE WHEN MeasureName='Success'		THEN Numerator	END)
	  ,Succ_Score				= max(CASE WHEN MeasureName='Success'		THEN Score		END)
	  ,HRFC19_EligSuccTimely	= max(CASE WHEN MeasureName='SuccTimely'	THEN Numerator	END)
	  ,SuccTimely_Score			= max(CASE WHEN MeasureName='SuccTimely'	THEN Score		END)
	  ,HRFC19_EligSuccUnTimely	= max(CASE WHEN MeasureName='SuccUnTimely'	THEN Numerator	END)
	  ,SuccUnTimely_Score		= max(CASE WHEN MeasureName='SuccUnTimely'	THEN Score		END)
	  ,HRFC19_EligUnable		= max(CASE WHEN MeasureName='Unsuccess'		THEN Numerator	END)
	  ,Unable_Score				= max(CASE WHEN MeasureName='Unsuccess'		THEN Score		END)
	  ,HRFC19_EligUnableTimely	= max(CASE WHEN MeasureName='UnableTimely'	THEN Numerator	END)
	  ,UnableTimely_Score		= max(CASE WHEN MeasureName='UnableTimely'	THEN Score		END)
	  ,HRFC19_EligUnableUnTimely= max(CASE WHEN MeasureName='UnableUnTimely'THEN Numerator	END)
	  ,UnableUnTimely_Score		= max(CASE WHEN MeasureName='UnableUnTimely'THEN Score		END)
	  ,HRFC19_EligDecline		= max(CASE WHEN MeasureName='Declined'		THEN Numerator	END)
	  ,Decl_Score				= max(CASE WHEN MeasureName='Declined'		THEN Score		END)
	  ,HRFC19_EligDeclTimely	= max(CASE WHEN MeasureName='DeclTimely'	THEN Numerator	END)
	  ,DeclTimely_Score			= max(CASE WHEN MeasureName='DeclTimely'	THEN Score		END)
	  ,HRFC19_EligDeclUnTimely	= max(CASE WHEN MeasureName='DeclUnTimely'	THEN Numerator	END)
	  ,DeclUnTimely_Score		= max(CASE WHEN MeasureName='DeclUnTimely'	THEN Score		END)
	  ,HRFC19_EligNotAtt		= max(CASE WHEN MeasureName='NotAtt'		THEN Numerator	END)
	  ,NotAtt_Score				= max(CASE WHEN MeasureName='NotAtt'		THEN Score		END)
	  ,MonthEnd
	  ,MeasureType='Monthly'
	  ,RunDate	= max(RunDate)
FROM [COVID].[HRF_SurveillanceFacility] f
INNER JOIN [LookUp].[ChecklistID] c on 
	c.ChecklistID=f.ChecklistID 
	AND c.VISN=f.VISN
WHERE MonthEnd = (SELECT max(MonthEnd) FROM [COVID].[HRF_SurveillanceFacility])
	AND MeasureType='M'
GROUP BY f.VISN,f.ChecklistID,c.ADMParent_FCDM,MonthEnd
--ORDER BY VISN,ADMPARENT_FCDM