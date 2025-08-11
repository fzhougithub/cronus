CREATE TABLE claim_core_p_319
PARTITION OF claim_core_p
FOR VALUES IN (319)
PARTITION BY RANGE (process_create_ts);

CREATE TABLE claim_core_p_544
PARTITION OF claim_core_p
FOR VALUES IN (544)
PARTITION BY RANGE9 (process_create_ts);

CREATE TABLE claim_core_p_828
PARTITION OF claim_core_p
FOR VALUES IN (828)
PARTITION BY RANGE9 (process_create_ts);

CREATE TABLE claim_core_p_829
PARTITION OF claim_core_p
FOR VALUES IN (829)
PARTITION BY RANGE9 (process_create_ts);

CREATE TABLE claim_core_p_830
PARTITION OF claim_core_p
FOR VALUES IN (830)
PARTITION BY RANGE9 (process_create_ts);

CREATE TABLE claim_core_p_837
PARTITION OF claim_core_p
FOR VALUES IN (837)
PARTITION BY RANGE9 (process_create_ts);
