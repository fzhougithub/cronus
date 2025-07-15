#!/bin/bash


db=postgres
PSQL=/usr/pgsql-14/bin/psql

dropTableSQL="DROP TABLE IF EXISTS misc.pg_log_errors"
tableSQL="CREATE TABLE misc.pg_log_errors
                ( pg_log_error_id bigserial PRIMARY KEY,
                  pg_log_error_ts       timestamp with time zone NOT NULL,
                  pg_log_tz        		varchar NOT NULL,
                  pg_log_errstr         varchar NOT NULL )"

echo "$dropTableSQL" | $PSQL $db
echo "$tableSQL" | $PSQL $db
