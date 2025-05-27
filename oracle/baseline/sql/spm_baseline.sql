SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_sql_id          VARCHAR2(13); -- SQL ID of the query
    v_plan_hash_value NUMBER;       -- Plan hash value of the query
    v_baseline_name   VARCHAR2(30) := 'MY_SQL_BASELINE'; -- Name for the baseline
    v_fixed           VARCHAR2(3)  := 'NO'; -- Whether the baseline is fixed ('YES' or 'NO')
BEGIN
    -- Step 1: Identify the SQL ID of a query (replace with your query)
    -- For demonstration, we'll use a sample query. Replace this with your actual query.
    EXECUTE IMMEDIATE 'SELECT sql_id FROM v$sql WHERE sql_text LIKE ''%SELECT * FROM employees%'' AND ROWNUM = 1'
        INTO v_sql_id;

    -- Step 2: Capture the current SQL plan for the SQL ID
    DBMS_OUTPUT.PUT_LINE('SQL ID: ' || v_sql_id);
    DBMS_OUTPUT.PUT_LINE('Current Plan:');
    EXECUTE IMMEDIATE 'SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(''' || v_sql_id || ''', NULL, ''ALLSTATS LAST''))';

    -- Step 3: Create a SQL plan baseline for the SQL ID
    -- First, capture the plan hash value (you can get this from DBA_HIST_SQL_PLAN or V$SQL_PLAN)
    SELECT plan_hash_value INTO v_plan_hash_value
    FROM v$sql_plan
    WHERE sql_id = v_sql_id
      AND ROWNUM = 1; -- Adjust this query to get the correct plan_hash_value

    -- Create the baseline using DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE
    DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(
        sql_id          => v_sql_id,
        plan_hash_value => v_plan_hash_value,
        fixed           => v_fixed, -- Set to 'YES' if you want to fix the baseline
        enabled         => 'YES', -- Enable the baseline
        name            => v_baseline_name -- Name for the baseline (optional)
    );

    DBMS_OUTPUT.PUT_LINE('SQL Plan Baseline created successfully with name: ' || v_baseline_name);

    -- Step 4: Verify the baseline was created
    DBMS_OUTPUT.PUT_LINE('Baseline Details:');
    FOR rec IN (
        SELECT sql_handle, plan_name, enabled, accepted, fixed
        FROM dba_sql_plan_baselines
        WHERE name = v_baseline_name
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('SQL Handle: ' || rec.sql_handle);
        DBMS_OUTPUT.PUT_LINE('Plan Name: ' || rec.plan_name);
        DBMS_OUTPUT.PUT_LINE('Enabled: ' || rec.enabled);
        DBMS_OUTPUT.PUT_LINE('Accepted: ' || rec.accepted);
        DBMS_OUTPUT.PUT_LINE('Fixed: ' || rec.fixed);
    END LOOP;

    -- Step 5: Demonstrate how to use the baseline
    -- When the same SQL statement is executed again, Oracle will try to use the baseline plan
    -- If the plan is not available, Oracle will capture a new plan and compare it with the baseline
    -- If the new plan is better, it will be added to the baseline; otherwise, the baseline plan will be used

    DBMS_OUTPUT.PUT_LINE('Executing the SQL statement again...');
    EXECUTE IMMEDIATE 'SELECT * FROM employees'; -- Replace with your query

    -- Step 6: Verify the baseline usage
    DBMS_OUTPUT.PUT_LINE('Current Plan after baseline usage:');
    EXECUTE IMMEDIATE 'SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(''' || v_sql_id || ''', NULL, ''ALLSTATS LAST''))';

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
