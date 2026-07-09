Yes, absolutely\! Both solutions (Loki + Promtail, and Custom Script + Node Exporter Textfile Collector) are highly adaptable and can be used to monitor and alert on **any `ERROR` or `WARNING` situation** (or any other log pattern) in your PostgreSQL logs, not just the logical replication errors.

Here's how they extend:

### 1\. Loki + Promtail for General Errors/Warnings

This is the ideal approach for comprehensive log monitoring because it allows you to centralize all your logs and query them flexibly.

  * **Promtail Configuration:**

      * You'd configure Promtail to send all log lines to Loki.
      * Within Promtail's `pipeline_stages`, you can add stages to extract the log level (`ERROR`, `WARNING`, `LOG`, etc.) and the message.
      * You can then create labels based on these extracted fields.

    **Example Promtail `pipeline_stages` for general log levels:**

    ```yaml
    scrape_configs:
      - job_name: postgresql-logs
        static_configs:
          - targets: [localhost]
            labels:
              job: postgresql-logs
              __path__: /pg_logs/postgresql-*.log* # Matches all rotated logs
        pipeline_stages:
          # Example for common stderr log_line_prefix: %t [%p]: [level]: message
          # Adjust regex based on your actual log_line_prefix and error message format
          - regex:
              expression: '^(?P<timestamp>\S+\s\S+)\s\[(?P<pid>\d+)\]:\s(?P<log_level>[A-Z]+):\s(?P<message>.*)$'
            # A simpler regex might just capture the level if your prefix is consistent
            # expression: '.*:\s(?P<log_level>ERROR|WARNING|FATAL|PANIC|LOG|NOTICE|INFO|DEBUG):\s(?P<message>.*)$'
          - labels:
              log_level: # From the captured group
          - output:
              source: message # Send the full message as the log line
    ```

    (You'll need to adjust the `regex` to precisely match your `log_line_prefix` and how the log level/message appear in your logs.)

  * **Grafana Dashboards & Alerting:**

      * **Dashboard Panels:**
          * You can create a panel showing `count_over_time({job="postgresql-logs"} |~ "(?i)error|warning"[5m])` to see a general trend of errors and warnings.
          * Another panel could use `count_over_time({job="postgresql-logs", log_level="ERROR"}[5m])` to specifically track errors.
          * You can then use Grafana's explore feature with LogQL to filter logs by `log_level="ERROR"` and search for specific keywords within the messages.
      * **Alert Rules:**
          * **General Error Alert:**
            ```yaml
            - alert: PostgresHighErrorRate
              expr: sum(count_over_time({job="postgresql-logs", log_level="ERROR"}[5m])) > 5
              for: 5m
              labels:
                severity: critical
              annotations:
                summary: "High error rate in PostgreSQL logs on {{ $labels.instance }}"
                description: "More than 5 ERROR messages detected in the last 5 minutes. Check logs for details."
            ```
          * **Specific Warning Alert:**
            ```yaml
            - alert: PostgresSpecificWarning
              expr: count_over_time({job="postgresql-logs"} |= "replication slot is not being used"[1h]) > 0
              for: 10m
              labels:
                severity: warning
              annotations:
                summary: "Specific replication slot warning detected on {{ $labels.instance }}"
                description: "A warning about an unused replication slot was found. Investigate."
            ```

### 2\. Custom Script + Node Exporter Textfile Collector for Specific Alerts

This method is more suitable if you only need to track a *few specific types* of errors or warnings and don't require full log search capabilities.

  * **Script Modification:**

      * You would create separate metrics for different error types or a single metric that aggregates all errors/warnings.
      * The `grep -c` part of the script would be modified to count different patterns.

    **Example Script for multiple error types:**

    ```bash
    #!/bin/bash

    LOG_FILE="/pg_logs/postgresql-23.log-20250724"
    OUTPUT_DIR="/var/lib/node_exporter/textfile_collector"
    OUTPUT_FILE="${OUTPUT_DIR}/pg_log_alerts.prom"

    mkdir -p "${OUTPUT_DIR}"

    # Count specific logical replication errors
    REPL_ERROR_COUNT=$(grep -c "logical replication error" "${LOG_FILE}")

    # Count general ERROR messages (adjust pattern if needed, e.g., to exclude specific errors)
    GENERAL_ERROR_COUNT=$(grep -c "ERROR:" "${LOG_FILE}")

    # Count WARNING messages
    WARNING_COUNT=$(grep -c "WARNING:" "${LOG_FILE}")

    # Output in Prometheus format
    cat <<EOF > "${OUTPUT_FILE}"
    # HELP postgres_log_replication_error_count Total count of specific logical replication errors in logs.
    # TYPE postgres_log_replication_error_count gauge
    postgres_log_replication_error_count ${REPL_ERROR_COUNT}

    # HELP postgres_log_general_error_count Total count of general ERROR messages in logs.
    # TYPE postgres_log_general_error_count gauge
    postgres_log_general_error_count ${GENERAL_ERROR_COUNT}

    # HELP postgres_log_warning_count Total count of WARNING messages in logs.
    # TYPE postgres_log_warning_count gauge
    postgres_log_warning_count ${WARNING_COUNT}
    EOF
    ```

    (Again, for production, you'd want to refine the counting logic to only process new log entries or entries within a specific time window to get a "rate" rather than a cumulative "total".)

  * **Prometheus Alert Rules:**
    You would then create separate alert rules in Prometheus for each of these new metrics, similar to the `HighLogicalReplicationErrors` example.

    ```yaml
    - alert: PostgresGeneralErrors
      expr: postgres_log_general_error_count > 10
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High general error count in PostgreSQL logs on {{ $labels.instance }}"

    - alert: PostgresWarningsDetected
      expr: postgres_log_warning_count > 0
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Warnings detected in PostgreSQL logs on {{ $labels.instance }}"
    ```

**In conclusion:** Yes, these solutions are highly flexible. Loki + Promtail provides a more comprehensive and scalable log management solution, while the custom script approach is a lighter-weight option for specific, predefined log patterns. The key is to get the log data (or counts derived from it) into a format that Prometheus can scrape and Grafana can visualize/alert on.
