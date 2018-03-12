
CREATE PROCEDURE tSQLt.Private_RunTestClass
  @TestClassName NVARCHAR(MAX)
AS
BEGIN
    DECLARE @TestCaseName NVARCHAR(MAX);
    DECLARE @TestClassId INT; SET @TestClassId = tSQLt.Private_GetSchemaId(@TestClassName);
    DECLARE @SetupProcName NVARCHAR(MAX);
    EXEC tSQLt.Private_GetSetupProcedureName @TestClassId, @SetupProcName OUTPUT;
    
    IF (@SetupProcName IS NOT NULL) EXEC @SetupProcName;

    DECLARE testCases CURSOR LOCAL FAST_FORWARD 
        FOR
	 SELECT tSQLt.Private_GetQuotedFullName(tests.object_id),
			tSQLt.Private_GetQuotedFullName(setups.object_id)
       FROM		sys.procedures tests
	  LEFT JOIN sys.procedures setups
			 ON STUFF(tests.name,1,4,'setup') = setups.name
      WHERE LOWER(tests.name) LIKE 'test%'
      UNION
	  SELECT tSQLt.Private_GetQuotedFullName(tests.object_id),
			 tSQLt.Private_GetQuotedFullName(setups.object_id)
       FROM	    sys.procedures tests
	  LEFT JOIN sys.procedures setups
			 ON REPLACE(tests.name,'test','setup') = setups.name
      WHERE LOWER(tests.name) LIKE '%test%'
      AND   tests.schema_id = @TestClassId
      ;

    OPEN testCases;
    
    FETCH NEXT FROM testCases INTO @TestCaseName, @SetupProcName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC tSQLt.Private_RunTest @TestCaseName, @SetupProcName;

        FETCH NEXT FROM testCases INTO @TestCaseName, @SetupProcName;
    END;

    CLOSE testCases;
    DEALLOCATE testCases;
END;
