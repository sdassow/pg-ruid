
\set ECHO 0

BEGIN;

\i test/sql/base/install.sql
\i test/sql/base/cast.sql
\i test/sql/base/uninstall.sql

ROLLBACK;

