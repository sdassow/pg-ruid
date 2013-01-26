
-- Adjust this setting to control where the objects get dropped.
SET search_path = public;

DROP OPERATOR CLASS ruid_ops USING hash;
DROP OPERATOR CLASS ruid_ops USING btree;

DROP OPERATOR =  (ruid,ruid);
DROP OPERATOR <> (ruid,ruid);
DROP OPERATOR <  (ruid,ruid);
DROP OPERATOR >  (ruid,ruid);
DROP OPERATOR <= (ruid,ruid);
DROP OPERATOR >= (ruid,ruid);

DROP CAST (uuid AS ruid);
DROP CAST (ruid AS uuid);

DROP FUNCTION ruid_eq(ruid, ruid);
DROP FUNCTION ruid_ne(ruid, ruid);
DROP FUNCTION ruid_lt(ruid, ruid);
DROP FUNCTION ruid_gt(ruid, ruid);
DROP FUNCTION ruid_le(ruid, ruid);
DROP FUNCTION ruid_ge(ruid, ruid);

DROP FUNCTION ruid_hash(ruid);
DROP FUNCTION ruid_cmp(ruid, ruid);

-- cascade to drop functions _in, _out, _recv and _send too.
DROP TYPE ruid CASCADE;

