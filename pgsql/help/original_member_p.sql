-- Partition 1
CREATE TABLE claim_dur_history_p_part_1 PARTITION OF claim_dur_history_p
FOR VALUES FROM (MINVALUE, MINVALUE, MINVALUE) TO (319, 9999, '00000002669913681');

-- Partition 2
CREATE TABLE claim_dur_history_p_part_2 PARTITION OF claim_dur_history_p
FOR VALUES FROM (319, 9999, '00000002669913681') TO (319, 9999, '00000003504889911');

-- Partition 3
CREATE TABLE claim_dur_history_p_part_3 PARTITION OF claim_dur_history_p
FOR VALUES FROM (319, 9999, '00000003504889911') TO (319, 9999, '00000004057262311');

-- Partition 4
CREATE TABLE claim_dur_history_p_part_4 PARTITION OF claim_dur_history_p
FOR VALUES FROM (319, 9999, '00000004057262311') TO (319, 9999, '00000004601141241');

-- Partition 5
CREATE TABLE claim_dur_history_p_part_5 PARTITION OF claim_dur_history_p
FOR VALUES FROM (319, 9999, '00000004601141241') TO (319, 9999, '00000006182422151');

-- Partition 6 (Note: client_id changes from 319 to 320, so the 'FROM' boundary for this partition
-- effectively starts from the next possible value after the last 319-based boundary)
CREATE TABLE claim_dur_history_p_part_6 PARTITION OF claim_dur_history_p
FOR VALUES FROM (319, 9999, '00000006182422151') TO (320, 9999, '00000000213270421');

-- Partition 7
CREATE TABLE claim_dur_history_p_part_7 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000000213270421') TO (320, 9999, '00000000641676651');

-- Partition 8
CREATE TABLE claim_dur_history_p_part_8 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000000641676651') TO (320, 9999, '00000001061805561');

-- Partition 9
CREATE TABLE claim_dur_history_p_part_9 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000001061805561') TO (320, 9999, '00000001464228881');

-- Partition 10
CREATE TABLE claim_dur_history_p_part_10 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000001464228881') TO (320, 9999, '00000001980575881');

-- Partition 11
CREATE TABLE claim_dur_history_p_part_11 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000001980575881') TO (320, 9999, '00000002297892801');

-- Partition 12
CREATE TABLE claim_dur_history_p_part_12 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000002297892801') TO (320, 9999, '00000002442643851');

-- Partition 13
CREATE TABLE claim_dur_history_p_part_13 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000002442643851') TO (320, 9999, '00000002567693381');

-- Partition 14
CREATE TABLE claim_dur_history_p_part_14 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000002567693381') TO (320, 9999, '00000002656673911');

-- Partition 15
CREATE TABLE claim_dur_history_p_part_15 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000002656673911') TO (320, 9999, '00000002902872931');

-- Partition 16
CREATE TABLE claim_dur_history_p_part_16 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000002902872931') TO (320, 9999, '00000003163801931');

-- Partition 17
CREATE TABLE claim_dur_history_p_part_17 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000003163801931') TO (320, 9999, '00000003553467561');

-- Partition 18
CREATE TABLE claim_dur_history_p_part_18 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000003553467561') TO (320, 9999, '00000003902899341');

-- Partition 19
CREATE TABLE claim_dur_history_p_part_19 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000003902899341') TO (320, 9999, '00000004095420581');

-- Partition 20
CREATE TABLE claim_dur_history_p_part_20 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000004095420581') TO (320, 9999, '00000004234297621');

-- Partition 21
CREATE TABLE claim_dur_history_p_part_21 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000004234297621') TO (320, 9999, '00000004335281051');

-- Partition 22
CREATE TABLE claim_dur_history_p_part_22 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000004335281051') TO (320, 9999, '00000004503477661');

-- Partition 23
CREATE TABLE claim_dur_history_p_part_23 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000004503477661') TO (320, 9999, '00000004642687011');

-- Partition 24
CREATE TABLE claim_dur_history_p_part_24 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000004642687011') TO (320, 9999, '00000004834241291');

-- Partition 25
CREATE TABLE claim_dur_history_p_part_25 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000004834241291') TO (320, 9999, '00000005023013861');

-- Partition 26
CREATE TABLE claim_dur_history_p_part_26 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000005023013861') TO (320, 9999, '00000005184413481');

-- Partition 27
CREATE TABLE claim_dur_history_p_part_27 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000005184413481') TO (320, 9999, '00000005439254851');

-- Partition 28
CREATE TABLE claim_dur_history_p_part_28 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000005439254851') TO (320, 9999, '00000005707551571');

-- Partition 29
CREATE TABLE claim_dur_history_p_part_29 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '00000005707551571') TO (320, 9999, '000000061134318101');

-- Partition 30
CREATE TABLE claim_dur_history_p_part_30 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000061134318101') TO (320, 9999, '000000090220821101');

-- Partition 31
CREATE TABLE claim_dur_history_p_part_31 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000090220821101') TO (320, 9999, '000000091753392501');

-- Partition 32
CREATE TABLE claim_dur_history_p_part_32 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000091753392501') TO (320, 9999, '000000093001753201');

-- Partition 33
CREATE TABLE claim_dur_history_p_part_33 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000093001753201') TO (320, 9999, '000000099157568101');

-- Partition 34
CREATE TABLE claim_dur_history_p_part_34 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000099157568101') TO (320, 9999, '000000099410295401');

-- Partition 35
CREATE TABLE claim_dur_history_p_part_35 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000099410295401') TO (320, 9999, '000000099608868801');

-- Partition 36
CREATE TABLE claim_dur_history_p_part_36 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000099608868801') TO (320, 9999, '000000099725694601');

-- Partition 37 (The last partition uses MAXVALUE for the upper bound)
CREATE TABLE claim_dur_history_p_part_37 PARTITION OF claim_dur_history_p
FOR VALUES FROM (320, 9999, '000000099725694601') TO (MAXVALUE, MAXVALUE, MAXVALUE);
