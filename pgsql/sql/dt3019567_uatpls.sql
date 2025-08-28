\set ECHO ALL
\du+ audit_event_ro
\du+ dt3019567

CREATE ROLE audit_event_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA audit_event TO audit_event_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA audit_event TO audit_event_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA audit_event TO audit_event_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit_event GRANT SELECT ON TABLES TO audit_event_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit_event GRANT SELECT ON SEQUENCES TO audit_event_ro;
GRANT audit_event_ro to dt3019567;
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
\du+ communication_ro
\du+ dt3019567

CREATE ROLE communication_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA communication TO communication_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA communication TO communication_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA communication TO communication_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA communication GRANT SELECT ON TABLES TO communication_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA communication GRANT SELECT ON SEQUENCES TO communication_ro;
GRANT communication_ro to dt3019567;
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
\du+ drug_ro
\du+ dt3019567

CREATE ROLE drug_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA drug TO drug_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA drug TO drug_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA drug TO drug_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA drug GRANT SELECT ON TABLES TO drug_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA drug GRANT SELECT ON SEQUENCES TO drug_ro;
GRANT drug_ro to dt3019567;
\set ECHO ALL
\du+ drugmgmt_ro
\du+ dt3019567

CREATE ROLE drugmgmt_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA drugmgmt TO drugmgmt_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA drugmgmt TO drugmgmt_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA drugmgmt TO drugmgmt_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA drugmgmt GRANT SELECT ON TABLES TO drugmgmt_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA drugmgmt GRANT SELECT ON SEQUENCES TO drugmgmt_ro;
GRANT drugmgmt_ro to dt3019567;
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
\du+ foundations_builder_ro
\du+ dt3019567

CREATE ROLE foundations_builder_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA foundations_builder TO foundations_builder_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA foundations_builder TO foundations_builder_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA foundations_builder TO foundations_builder_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA foundations_builder GRANT SELECT ON TABLES TO foundations_builder_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA foundations_builder GRANT SELECT ON SEQUENCES TO foundations_builder_ro;
GRANT foundations_builder_ro to dt3019567;
\set ECHO ALL
\du+ global_ro
\du+ dt3019567

CREATE ROLE global_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA global TO global_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA global TO global_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA global TO global_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA global GRANT SELECT ON TABLES TO global_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA global GRANT SELECT ON SEQUENCES TO global_ro;
GRANT global_ro to dt3019567;
\set ECHO ALL
\du+ iidr_admin_ro
\du+ dt3019567

CREATE ROLE iidr_admin_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA iidr_admin TO iidr_admin_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA iidr_admin TO iidr_admin_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA iidr_admin TO iidr_admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA iidr_admin GRANT SELECT ON TABLES TO iidr_admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA iidr_admin GRANT SELECT ON SEQUENCES TO iidr_admin_ro;
GRANT iidr_admin_ro to dt3019567;
\set ECHO ALL
\du+ iidr_uatpls_ods_admin_ro
\du+ dt3019567

CREATE ROLE iidr_uatpls_ods_admin_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA iidr_uatpls_ods_admin TO iidr_uatpls_ods_admin_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA iidr_uatpls_ods_admin TO iidr_uatpls_ods_admin_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA iidr_uatpls_ods_admin TO iidr_uatpls_ods_admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA iidr_uatpls_ods_admin GRANT SELECT ON TABLES TO iidr_uatpls_ods_admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA iidr_uatpls_ods_admin GRANT SELECT ON SEQUENCES TO iidr_uatpls_ods_admin_ro;
GRANT iidr_uatpls_ods_admin_ro to dt3019567;
\set ECHO ALL
\du+ s_ods_admin_ro
\du+ dt3019567

CREATE ROLE s_ods_admin_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA s_ods_admin TO s_ods_admin_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA s_ods_admin TO s_ods_admin_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA s_ods_admin TO s_ods_admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA s_ods_admin GRANT SELECT ON TABLES TO s_ods_admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA s_ods_admin GRANT SELECT ON SEQUENCES TO s_ods_admin_ro;
GRANT s_ods_admin_ro to dt3019567;
\set ECHO ALL
\du+ informatica_etl_ro
\du+ dt3019567

CREATE ROLE informatica_etl_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA informatica_etl TO informatica_etl_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA informatica_etl TO informatica_etl_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA informatica_etl TO informatica_etl_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA informatica_etl GRANT SELECT ON TABLES TO informatica_etl_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA informatica_etl GRANT SELECT ON SEQUENCES TO informatica_etl_ro;
GRANT informatica_etl_ro to dt3019567;
\set ECHO ALL
\du+ lists_ro
\du+ dt3019567

CREATE ROLE lists_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA lists TO lists_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA lists TO lists_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA lists TO lists_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA lists GRANT SELECT ON TABLES TO lists_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA lists GRANT SELECT ON SEQUENCES TO lists_ro;
GRANT lists_ro to dt3019567;
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
\set ECHO ALL
\du+ planconfig_ro
\du+ dt3019567

CREATE ROLE planconfig_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA planconfig TO planconfig_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA planconfig TO planconfig_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA planconfig TO planconfig_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA planconfig GRANT SELECT ON TABLES TO planconfig_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA planconfig GRANT SELECT ON SEQUENCES TO planconfig_ro;
GRANT planconfig_ro to dt3019567;
\set ECHO ALL
\du+ program_mandate_ro
\du+ dt3019567

CREATE ROLE program_mandate_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA program_mandate TO program_mandate_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA program_mandate TO program_mandate_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA program_mandate TO program_mandate_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA program_mandate GRANT SELECT ON TABLES TO program_mandate_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA program_mandate GRANT SELECT ON SEQUENCES TO program_mandate_ro;
GRANT program_mandate_ro to dt3019567;
\set ECHO ALL
\du+ public_ro
\du+ dt3019567

CREATE ROLE public_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA public TO public_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO public_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO public_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO public_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO public_ro;
GRANT public_ro to dt3019567;
\set ECHO ALL
\du+ repack_ro
\du+ dt3019567

CREATE ROLE repack_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA repack TO repack_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA repack TO repack_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA repack TO repack_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA repack GRANT SELECT ON TABLES TO repack_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA repack GRANT SELECT ON SEQUENCES TO repack_ro;
GRANT repack_ro to dt3019567;
\set ECHO ALL
\du+ reporting_ro
\du+ dt3019567

CREATE ROLE reporting_ro;
-- CREATE ROLE dt3019567 WITH LOGIN PASSWORD ';
GRANT USAGE ON SCHEMA reporting TO reporting_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA reporting TO reporting_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA reporting TO reporting_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA reporting GRANT SELECT ON TABLES TO reporting_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA reporting GRANT SELECT ON SEQUENCES TO reporting_ro;
GRANT reporting_ro to dt3019567;
