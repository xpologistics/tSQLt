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

		EXEC ('DROP TABLE ' + @NewName);

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
