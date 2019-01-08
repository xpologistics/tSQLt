IF OBJECT_ID('tSQLt.FakeTable') IS NOT NULL DROP PROCEDURE tSQLt.FakeTable;
GO
---Build+
CREATE PROCEDURE tSQLt.FakeTable
    @TableName NVARCHAR(MAX),
    @SchemaName NVARCHAR(MAX) = NULL, --parameter preserved for backward compatibility. Do not use. Will be removed soon.
    @Identity BIT = NULL,
    @ComputedColumns BIT = NULL,
    @Defaults BIT = NULL,
    @Clone BIT = 0
AS
BEGIN
   DECLARE @OrigSchemaName NVARCHAR(MAX);
   DECLARE @OrigTableName NVARCHAR(MAX);
   DECLARE @NewNameOfOriginalTable NVARCHAR(4000);
   DECLARE @OrigTableFullName NVARCHAR(MAX); SET @OrigTableFullName = NULL;
   
   SELECT @OrigSchemaName = @SchemaName,
          @OrigTableName = @TableName
   
   IF(@OrigTableName NOT IN (PARSENAME(@OrigTableName,1),QUOTENAME(PARSENAME(@OrigTableName,1)))
      AND @OrigSchemaName IS NOT NULL)
   BEGIN
     RAISERROR('When @TableName is a multi-part identifier, @SchemaName must be NULL!',16,10);
   END

   SELECT @SchemaName = CleanSchemaName,
          @TableName = CleanTableName
     FROM tSQLt.Private_ResolveFakeTableNamesForBackwardCompatibility(@TableName, @SchemaName);
   
   EXEC tSQLt.Private_ValidateFakeTableParameters @SchemaName,@OrigTableName,@OrigSchemaName;

   EXEC tSQLt.Private_RenameObjectToUniqueName @SchemaName, @TableName, @NewNameOfOriginalTable OUTPUT;

   SELECT @OrigTableFullName = S.base_object_name
     FROM sys.synonyms AS S 
    WHERE S.object_id = OBJECT_ID(@SchemaName + '.' + @NewNameOfOriginalTable);

   IF(@OrigTableFullName IS NOT NULL)
   BEGIN
     IF(COALESCE(OBJECT_ID(@OrigTableFullName,'U'),OBJECT_ID(@OrigTableFullName,'V')) IS NULL)
     BEGIN
       RAISERROR('Cannot fake synonym %s.%s as it is pointing to %s, which is not a table or view!',16,10,@SchemaName,@TableName,@OrigTableFullName);
     END;
   END;
   ELSE
   BEGIN
     SET @OrigTableFullName = @SchemaName + '.' + @NewNameOfOriginalTable;
   END;

   IF (@Clone = 1)
     EXEC tSQLt.Private_CreateFakeCloneOfTable @SchemaName, @TableName, @OrigTableFullName;
   ELSE
     EXEC tSQLt.Private_CreateFakeOfTable @SchemaName, @TableName, @OrigTableFullName, @Identity, @ComputedColumns, @Defaults;

   EXEC tSQLt.Private_MarkFakeTable @SchemaName, @TableName, @NewNameOfOriginalTable;
END
GO

CREATE PROCEDURE tSQLt.Private_UnFakeTable
    @TableName NVARCHAR(MAX) = NULL
AS
BEGIN
	DECLARE @NewName SYSNAME;
	DECLARE @UnquotedSchemaName SYSNAME;
	DECLARE @UnquotedTableName SYSNAME;
	DECLARE @SchemaName SYSNAME;
	DECLARE @ObjectName SYSNAME;
	DECLARE	@ObjectId INT;

	DECLARE FakeTableCursor CURSOR
	READ_ONLY FORWARD_ONLY
	FOR
	SELECT	 OBJECT_SCHEMA_NAME(ObjectId) as SchemaName
			,OBJECT_NAME(ObjectId) as ObjectName
			,OriginalName as NewName
			,ObjectId
	FROM	tSQLt.Private_RenamedObjectLog
	WHERE	(	@TableName = OBJECT_NAME(ObjectId)
			OR	@TableName IS NULL
			)
	AND		ObjectId IS NOT NULL
	ORDER BY
			Id DESC;

	OPEN FakeTableCursor;

	WHILE(1=1)
	BEGIN
		FETCH NEXT FROM FakeTableCursor INTO @SchemaName, @ObjectName, @NewName, @ObjectId;
		IF (@@FETCH_STATUS != 0)
			BREAK;

		SET @UnquotedSchemaName = OBJECT_SCHEMA_NAME(OBJECT_ID(@SchemaName+'.'+@ObjectName));
		SET @UnquotedTableName = OBJECT_NAME(OBJECT_ID(@ObjectName));
		SET @NewName = PARSENAME(@NewName, 1)
		SET	@ObjectName = PARSENAME(@UnquotedSchemaName + '.' + @UnquotedTableName, 1);

		BEGIN TRAN

		IF EXISTS (
			SELECT	1
			FROM	sys.extended_properties
			WHERE	NAME = N'tSQLt.FakeTable_OrgTableName'
			AND		VALUE = @ObjectName)
				EXEC sys.sp_dropextendedproperty 
					@name = N'tSQLt.FakeTable_OrgTableName', 
					@level0type = N'SCHEMA', @level0name = @UnquotedSchemaName, 
					@level1type = N'TABLE',  @level1name = @NewName;

		EXEC ('DROP TABLE [' + @UnquotedSchemaName + '].[' + @NewName + ']');

		EXEC sp_rename 
			@objname = @ObjectName, 
			@newname = @NewName,
			@objtype = 'OBJECT';

		DELETE
		FROM	tSQLt.Private_RenamedObjectLog
		WHERE	ObjectId = @ObjectId;

		COMMIT TRAN;

	END;
  
	CLOSE FakeTableCursor;
	DEALLOCATE FakeTableCursor;

END
GO
---Build-

