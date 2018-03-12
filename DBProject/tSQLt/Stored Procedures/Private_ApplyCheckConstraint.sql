
CREATE PROCEDURE tSQLt.Private_ApplyCheckConstraint
  @ConstraintObjectId INT
AS
BEGIN
  DECLARE @Cmd NVARCHAR(MAX);
  SELECT @Cmd = 'CONSTRAINT ' + QUOTENAME(name) + ' CHECK' + definition 
    FROM sys.check_constraints
   WHERE object_id = @ConstraintObjectId;
  
  DECLARE @QuotedTableName NVARCHAR(MAX);
  
  SELECT @QuotedTableName = QuotedTableName FROM tSQLt.Private_GetQuotedTableNameForConstraint(@ConstraintObjectId);

  EXEC tSQLt.Private_RenameObjectToUniqueNameUsingObjectId @ConstraintObjectId;
  SELECT @Cmd = 'ALTER TABLE ' + @QuotedTableName + ' ADD ' + @Cmd
    FROM sys.objects 
   WHERE object_id = @ConstraintObjectId;

  IF (	SELECT	CASE transaction_isolation_level 
				WHEN 0 THEN 'Unspecified' 
				WHEN 1 THEN 'ReadUncommitted' 
				WHEN 2 THEN 'ReadCommitted' 
				WHEN 3 THEN 'Repeatable' 
				WHEN 4 THEN 'Serializable' 
				WHEN 5 THEN 'Snapshot' END AS TRANSACTION_ISOLATION_LEVEL 
		FROM	sys.dm_exec_sessions 
		WHERE	session_id = @@SPID 
	  ) = 'Snapshot'
    PRINT 'Not created due to transaction_isolation_level = Snapshot: ' + @Cmd;
  ELSE
    EXEC (@Cmd);

END; 
