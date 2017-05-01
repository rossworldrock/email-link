DROP TABLE #dups
#Adding a comment to check flow
SELECT accountnumber
INTO #dups
FROM  [InternetData].[dbo].[Email_Test_Account]
Where [TestName] = 'CD_20161205-5050Split-GiftsforYou'
GROUP BY accountnumber
HAVING COUNT(DISTINCT mailinggroup) > 1;

DROP TABLE #testtable

SELECT accountnumber
      ,mailinggroup
INTO #testtable
FROM  [InternetData].[dbo].[Email_Test_Account]
WHERE[TestName] = 'CD_20161205-5050Split-GiftsforYou' AND accountnumber NOT IN (
                        SELECT accountnumber
                        FROM #dups
                        )
GROUP BY accountnumber
       ,mailinggroup

SELECT mailinggroup
            ,COUNT(*)
FROM #testtable
GROUP BY mailinggroup
ORDER BY mailinggroup;


DECLARE @mailingid TABLE (mailingid int)
INSERT INTO @mailingid values (27230299)
INSERT INTO @mailingid values (27233072)
SELECT MailingId
       ,ReportId
       ,MailingName
       ,SentDateTime
       ,NumSent
       ,NumBounceHard
       ,NumBounceSoft
       ,NumUniqueOpen
       ,NumUniqueClick
       ,companycode
       ,EmailType
       ,StartDate
       ,EmailSubType
       ,TestGroup
       ,LongMailingName
FROM internetdata.dbo.email_summary
WHERE mailingid IN (SELECT mailingid from @mailingid)

SELECT mailingid
            ,mailinggroup
            ,COUNT(distinct ev.accountnumber)
FROM 
#testtable tt
JOIN 
 mdw1.dbo.emailEvent2016 ev WITH (NOLOCK)
ON tt.accountnumber = ev.accountnumber
WHERE eventType = 'Sent' AND EventDate > '20161110' 
AND mailingid IN (SELECT mailingid from @mailingid)
GROUP BY mailingid
            ,mailinggroup
ORDER BY mailinggroup, mailingid;


DROP TABLE #sales

DECLARE @COMPANY VARCHAR(1)
SET @COMPANY = 'C'
DECLARE @STARTDATE VARCHAR(8)
SET @STARTDATE = '20161204'
DECLARE @ENDDATE VARCHAR(8)
SET @ENDDATE = '20161231'

SELECT mailinggroup
            ,f.ACCOUNTNUMBER
            ,ordertotal
            ,ordernumber
            ,receiveddate
            ,ORDERTYPE
            ,isnull(NAME,discountid) as NAME
            ,code
            ,discountoffercode
            ,Postage
            ,Remittance
            ,AmountDue
            ,casbaddebtestimate
            ,arfactoredprojectedbaddebt
            ,discountamount
            ,discountid
into #sales                   
FROM mdw1.dbo.currentorders co WITH (NOLOCK)
INNER JOIN #testtable f WITH (NOLOCK) 
ON co.accountnumber = f.accountnumber 
LEFT JOIN (
            SELECT NAME
                        ,code
                        ,site
                        ,MAX(mf_code) AS mf_code
            FROM internetdata.dbo.promocode_master pm WITH (NOLOCK)
            GROUP BY NAME
                        ,code
                        ,site
            ) AS pm ON discountid = code 
            AND pm.site = @COMPANY
WHERE receiveddate BETWEEN @STARTDATE AND @ENDDATE 
AND orderstatus = 'F' 
AND co.companycode = @COMPANY AND ordertotal > 0;

SELECT mailinggroup                      
      -- ,receiveddate                   
       ,COUNT(DISTINCT ACCOUNTNUMBER) AS ACCOUNTSwOrders                  
       ,sum(ordertotal) AS sales                
       ,count(ordernumber) AS orders                   
       ,sum(discountamount) AS discount                
       ,sum(CASE                  
                     WHEN discountamount IS NULL 
                           OR discountamount <= 0
                           THEN 0
                     ELSE 1 
                     END) AS discount_orders    
       ,sum(CASE                  
                     WHEN arfactoredprojectedbaddebt = 0      
                           AND ORDERTYPE = 'CC'
                           THEN (AmountDue - Remittance) * (casbaddebtestimate * .01)
                     ELSE arfactoredprojectedbaddebt   
                     END) AS baddebt      
       ,sum(CASE                  
                     WHEN discountamount IS NULL 
                           OR discountamount <= 0
                           THEN 0
                     ELSE ordertotal      
                     END) AS discount_sales                          
FROM #sales                  
GROUP BY mailinggroup                           
          --  ,receiveddate        
ORDER BY --receiveddate,                        
mailinggroup DESC     

select * from #sales



