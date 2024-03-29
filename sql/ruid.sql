/*
 * Copyright (c) 2010-2013 Simon Bertrang <janus@errornet.de>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

SET search_path TO public;
SET client_min_messages TO warning;

--
--  the RUID data type
--

CREATE FUNCTION
    ruid_in(CSTRING) RETURNS ruid
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_in'
;

CREATE FUNCTION
    ruid_out(ruid) RETURNS CSTRING
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_out'
;

CREATE FUNCTION
    ruid_recv(INTERNAL) RETURNS ruid
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_recv'
;

CREATE FUNCTION
    ruid_send(ruid) RETURNS BYTEA
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_send'
;

CREATE TYPE ruid (
    INPUT   = ruid_in,   -- for SQL input
    OUTPUT  = ruid_out,  -- for SQL output
    RECEIVE = ruid_recv, -- for DB input
    SEND    = ruid_send, -- for DB output
--    DEFAULT = 'ruid(1)',
    INTERNALLENGTH = 16,
    ALIGNMENT = char
);

COMMENT ON TYPE ruid
    IS 'RUID type'
;

CREATE CAST (ruid AS uuid)
    WITHOUT FUNCTION AS ASSIGNMENT
;
CREATE CAST (uuid AS ruid)
    WITHOUT FUNCTION AS ASSIGNMENT
;


--
--  the RUID operators
--

CREATE FUNCTION
    ruid_eq(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_eq'
;

CREATE FUNCTION
    ruid_ne(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_ne'
;

CREATE FUNCTION
    ruid_lt(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_lt'
;

CREATE FUNCTION
    ruid_gt(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_gt'
;

CREATE FUNCTION
    ruid_le(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_le'
;

CREATE FUNCTION
    ruid_ge(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_ge'
;

CREATE OPERATOR = (
    leftarg    = ruid,
    rightarg   = ruid,
    negator    = <>,
    procedure  = ruid_eq
);

CREATE OPERATOR <> (
    leftarg    = ruid,
    rightarg   = ruid,
    negator    = =,
    procedure  = ruid_ne
);

CREATE OPERATOR < (
    leftarg    = ruid,
    rightarg   = ruid,
    commutator = >,
    negator    = >=,
    procedure  = ruid_lt
);

CREATE OPERATOR > (
    leftarg    = ruid,
    rightarg   = ruid,
    commutator = <,
    negator    = <=,
    procedure  = ruid_gt
);

CREATE OPERATOR <= (
    leftarg    = ruid,
    rightarg   = ruid,
    commutator = >=,
    negator    = >,
    procedure  = ruid_le
);

CREATE OPERATOR >= (
    leftarg    = ruid,
    rightarg   = ruid,
    commutator = <=,
    negator    = <,
    procedure  = ruid_ge
);

--
--  index support
--

CREATE FUNCTION
    ruid_hash(ruid) RETURNS INTEGER
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_hash'
;

CREATE FUNCTION
    ruid_cmp(ruid, ruid) RETURNS INTEGER
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_cmp'
;

CREATE OPERATOR CLASS ruid_ops
    DEFAULT FOR TYPE ruid USING hash AS
    OPERATOR 1 =,   -- 1: equal
    FUNCTION 1 ruid_hash(ruid)
;

CREATE OPERATOR CLASS ruid_ops
  DEFAULT FOR TYPE ruid USING btree AS
    OPERATOR 1 <       (ruid, ruid), -- 1: less than
    OPERATOR 2 <=      (ruid, ruid), -- 2: less than or equal
    OPERATOR 3 =       (ruid, ruid), -- 3: equal
    OPERATOR 4 >=      (ruid, ruid), -- 4: greater than or equal
    OPERATOR 5 >       (ruid, ruid), -- 5: greater than
    FUNCTION 1 ruid_cmp(ruid, ruid)
;

--
-- helper functions
--

CREATE OR REPLACE FUNCTION ruid_nil()
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT 'AAAAAAAAAAAAAAAAAAAAAA'::ruid
$$;

CREATE FUNCTION ruid_ns_dns()
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_ns_dns()::ruid
$$;

CREATE FUNCTION ruid_ns_oid()
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_ns_oid()::ruid
$$;

CREATE FUNCTION ruid_ns_url()
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_ns_url()::ruid
$$;

CREATE FUNCTION ruid_ns_x500()
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_ns_x500()::ruid
$$;

CREATE FUNCTION ruid_v1()
  RETURNS ruid LANGUAGE sql AS $$
SELECT uuid_generate_v1()::ruid
$$;

CREATE FUNCTION ruid_v1mc()
  RETURNS ruid LANGUAGE sql AS $$
SELECT uuid_generate_v1mc()::ruid
$$;

CREATE FUNCTION ruid_v4()
  RETURNS ruid LANGUAGE sql AS $$
SELECT uuid_generate_v4()::ruid
$$;

CREATE FUNCTION ruid_v5(ruid, text)
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_generate_v5($1::uuid, $2)::ruid
$$;

CREATE FUNCTION ruid_dns(text)
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_generate_v5(uuid_ns_dns(), trim($1))::ruid
$$;

CREATE FUNCTION ruid_oid(text)
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_generate_v5(uuid_ns_oid(), trim($1))::ruid
$$;

CREATE FUNCTION ruid_url(text)
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_generate_v5(uuid_ns_url(), trim($1))::ruid
$$;

CREATE FUNCTION ruid_x500(text)
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_generate_v5(uuid_ns_x500(), trim($1))::ruid
$$;

CREATE OR REPLACE FUNCTION ruid_sum(text)
  RETURNS ruid LANGUAGE sql IMMUTABLE AS $$
SELECT uuid_generate_v5(uuid_nil(), $1)::ruid
$$;

