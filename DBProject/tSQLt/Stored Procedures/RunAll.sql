﻿CREATE PROCEDURE tSQLt.RunAll
AS
BEGIN
  EXEC tSQLt.Private_RunMethodHandler @RunMethod = 'tSQLt.Private_RunAll';
  EXEC tSQLt.Private_UnFakeTable;
END;
