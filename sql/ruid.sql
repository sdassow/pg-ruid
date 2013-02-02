--
--  ruid - Readable Unique Identifier
--
--  Copyright (c) 2004-2007 Ralf S. Engelschall <rse@engelschall.com>
--  Copyright (c) 2004-2007 The OSSP Project <http://www.ossp.org/>
--
--  Permission to use, copy, modify, and distribute this software for
--  any purpose with or without fee is hereby granted, provided that
--  the above copyright notice and this permission notice appear in all
--  copies.
--
--  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
--  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
--  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
--  IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
--  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
--  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
--  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
--  USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
--  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
--  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
--  SUCH DAMAGE.
--

SET search_path TO public;
SET client_min_messages TO warning;

--
--  the RUID data type
--

CREATE FUNCTION
    ruid_in(CSTRING) RETURNS ruid
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_in';

CREATE FUNCTION
    ruid_out(ruid) RETURNS CSTRING
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_out';

CREATE FUNCTION
    ruid_recv(INTERNAL) RETURNS ruid
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_recv';

CREATE FUNCTION
    ruid_send(ruid) RETURNS BYTEA
    STRICT
    LANGUAGE C AS 'ruid', 'ruid_send';

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
    IS 'RUID type';

-- CREATE CAST (CSTRING AS ruid)
--     WITH FUNCTION ruid_in(CSTRING) AS ASSIGNMENT;
-- 
-- CREATE CAST (ruid AS CSTRING)
--     WITH FUNCTION ruid_out(ruid)   AS ASSIGNMENT;
CREATE CAST (ruid AS uuid)
    WITHOUT FUNCTION AS ASSIGNMENT;
CREATE CAST (uuid AS ruid)
    WITHOUT FUNCTION AS ASSIGNMENT;


--
--  the UUID constructor function
--

--
--  the UUID operators
--

CREATE FUNCTION
    ruid_eq(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_eq';

CREATE FUNCTION
    ruid_ne(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_ne';

CREATE FUNCTION
    ruid_lt(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_lt';

CREATE FUNCTION
    ruid_gt(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_gt';

CREATE FUNCTION
    ruid_le(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_le';

CREATE FUNCTION
    ruid_ge(ruid, ruid) RETURNS BOOL
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_ge';

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
    LANGUAGE C AS 'ruid', 'ruid_hash';

CREATE FUNCTION
    ruid_cmp(ruid, ruid) RETURNS INTEGER
    IMMUTABLE STRICT
    LANGUAGE C AS 'ruid', 'ruid_cmp';

CREATE OPERATOR CLASS ruid_ops
    DEFAULT FOR TYPE ruid USING hash AS
    OPERATOR 1 =,   -- 1: equal
    FUNCTION 1 ruid_hash(ruid);

CREATE OPERATOR CLASS ruid_ops
    DEFAULT FOR TYPE ruid USING btree AS
    OPERATOR 1 <       (ruid, ruid), -- 1: less than
    OPERATOR 2 <=      (ruid, ruid), -- 2: less than or equal
    OPERATOR 3 =       (ruid, ruid), -- 3: equal
    OPERATOR 4 >=      (ruid, ruid), -- 4: greater than or equal
    OPERATOR 5 >       (ruid, ruid), -- 5: greater than
    FUNCTION 1 ruid_cmp(ruid, ruid);

