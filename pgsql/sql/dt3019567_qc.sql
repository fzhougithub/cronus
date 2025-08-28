\set ECHO ALL
\du+ claimsprocess_ro
\du+ dt3019567

CREATE ROLE claimsprocess_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA claimsprocess TO claimsprocess_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA claimsprocess TO claimsprocess_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA claimsprocess TO claimsprocess_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA claimsprocess GRANT SELECT ON TABLES TO claimsprocess_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA claimsprocess GRANT SELECT ON SEQUENCES TO claimsprocess_ro;
GRANT claimsprocess_ro to dt3019567;
\set ECHO ALL
\du+ claimsprocess_humana_ro
\du+ dt3019567

CREATE ROLE claimsprocess_humana_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA claimsprocess_humana TO claimsprocess_humana_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA claimsprocess_humana TO claimsprocess_humana_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA claimsprocess_humana TO claimsprocess_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA claimsprocess_humana GRANT SELECT ON TABLES TO claimsprocess_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA claimsprocess_humana GRANT SELECT ON SEQUENCES TO claimsprocess_humana_ro;
GRANT claimsprocess_humana_ro to dt3019567;
\set ECHO ALL
\du+ claimsprocess_other_ro
\du+ dt3019567

CREATE ROLE claimsprocess_other_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA claimsprocess_other TO claimsprocess_other_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA claimsprocess_other TO claimsprocess_other_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA claimsprocess_other TO claimsprocess_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA claimsprocess_other GRANT SELECT ON TABLES TO claimsprocess_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA claimsprocess_other GRANT SELECT ON SEQUENCES TO claimsprocess_other_ro;
GRANT claimsprocess_other_ro to dt3019567;
\set ECHO ALL
\du+ customer_ro
\du+ dt3019567

CREATE ROLE customer_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA customer TO customer_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA customer TO customer_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA customer TO customer_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA customer GRANT SELECT ON TABLES TO customer_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA customer GRANT SELECT ON SEQUENCES TO customer_ro;
GRANT customer_ro to dt3019567;
\set ECHO ALL
\du+ finance_ro
\du+ dt3019567

CREATE ROLE finance_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA finance TO finance_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA finance TO finance_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA finance TO finance_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance GRANT SELECT ON TABLES TO finance_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance GRANT SELECT ON SEQUENCES TO finance_ro;
GRANT finance_ro to dt3019567;
\set ECHO ALL
\du+ finance_global_ro
\du+ dt3019567

CREATE ROLE finance_global_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA finance_global TO finance_global_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA finance_global TO finance_global_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA finance_global TO finance_global_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_global GRANT SELECT ON TABLES TO finance_global_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_global GRANT SELECT ON SEQUENCES TO finance_global_ro;
GRANT finance_global_ro to dt3019567;
\set ECHO ALL
\du+ finance_humana_ro
\du+ dt3019567

CREATE ROLE finance_humana_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA finance_humana TO finance_humana_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA finance_humana TO finance_humana_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA finance_humana TO finance_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_humana GRANT SELECT ON TABLES TO finance_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_humana GRANT SELECT ON SEQUENCES TO finance_humana_ro;
GRANT finance_humana_ro to dt3019567;
\set ECHO ALL
\du+ finance_misc_ro
\du+ dt3019567

CREATE ROLE finance_misc_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA finance_misc TO finance_misc_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA finance_misc TO finance_misc_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA finance_misc TO finance_misc_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_misc GRANT SELECT ON TABLES TO finance_misc_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_misc GRANT SELECT ON SEQUENCES TO finance_misc_ro;
GRANT finance_misc_ro to dt3019567;
\set ECHO ALL
\du+ finance_other_ro
\du+ dt3019567

CREATE ROLE finance_other_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA finance_other TO finance_other_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA finance_other TO finance_other_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA finance_other TO finance_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_other GRANT SELECT ON TABLES TO finance_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_other GRANT SELECT ON SEQUENCES TO finance_other_ro;
GRANT finance_other_ro to dt3019567;
\set ECHO ALL
\du+ misc_ro
\du+ dt3019567

CREATE ROLE misc_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA misc TO misc_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA misc TO misc_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA misc TO misc_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA misc GRANT SELECT ON TABLES TO misc_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA misc GRANT SELECT ON SEQUENCES TO misc_ro;
GRANT misc_ro to dt3019567;
\set ECHO ALL
\du+ misc_humana_ro
\du+ dt3019567

CREATE ROLE misc_humana_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA misc_humana TO misc_humana_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA misc_humana TO misc_humana_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA misc_humana TO misc_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA misc_humana GRANT SELECT ON TABLES TO misc_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA misc_humana GRANT SELECT ON SEQUENCES TO misc_humana_ro;
GRANT misc_humana_ro to dt3019567;
\set ECHO ALL
\du+ misc_other_ro
\du+ dt3019567

CREATE ROLE misc_other_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA misc_other TO misc_other_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA misc_other TO misc_other_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA misc_other TO misc_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA misc_other GRANT SELECT ON TABLES TO misc_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA misc_other GRANT SELECT ON SEQUENCES TO misc_other_ro;
GRANT misc_other_ro to dt3019567;
\set ECHO ALL
\du+ pct_global_ro
\du+ dt3019567

CREATE ROLE pct_global_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA pct_global TO pct_global_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA pct_global TO pct_global_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA pct_global TO pct_global_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA pct_global GRANT SELECT ON TABLES TO pct_global_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA pct_global GRANT SELECT ON SEQUENCES TO pct_global_ro;
GRANT pct_global_ro to dt3019567;
\set ECHO ALL
\du+ pct_humana_ro
\du+ dt3019567

CREATE ROLE pct_humana_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA pct_humana TO pct_humana_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA pct_humana TO pct_humana_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA pct_humana TO pct_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA pct_humana GRANT SELECT ON TABLES TO pct_humana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA pct_humana GRANT SELECT ON SEQUENCES TO pct_humana_ro;
GRANT pct_humana_ro to dt3019567;
\set ECHO ALL
\du+ pct_other_ro
\du+ dt3019567

CREATE ROLE pct_other_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA pct_other TO pct_other_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA pct_other TO pct_other_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA pct_other TO pct_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA pct_other GRANT SELECT ON TABLES TO pct_other_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA pct_other GRANT SELECT ON SEQUENCES TO pct_other_ro;
GRANT pct_other_ro to dt3019567;
