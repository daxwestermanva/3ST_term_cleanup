


CREATE VIEW
[REACH].[ReleaseDates]
as
	SELECT ReleaseDate
		  ,month(ReleaseDate) as ReleaseMonth
		  ,year(ReleaseDate) as ReleaseYear
		  ,MetricDays=DateDiff(d,ReleaseDate,lead(ReleaseDate) OVER (order by ReleaseDate))
		  --,EndDate
	FROM (
		SELECT IsNull(h.ReleaseDate,a.ReleaseDate) ReleaseDate 
		FROM(
			SELECT cast(Date as date) ReleaseDate, DayOfMonth, row_number() OVER(PARTITION BY CalendarYear, MonthOfYear ORDER BY DayOfMonth) AS WednesdayOfMonth  
			FROM [Dim].[Date] WITH (NOLOCK) 
			WHERE  dayname = 'Wednesday' AND date > '2016-11-01'
			) a
		LEFT JOIN (SELECT DISTINCT ReleaseDate FROM [REACH].[RiskScoreHistoric] WITH (NOLOCK)) h 
			on month(h.ReleaseDate)=month(a.ReleaseDate) and year(h.ReleaseDate)=year(a.ReleaseDate)
		WHERE WednesdayOfMonth=2
		) b