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

#include "postgres.h"

#include "access/hash.h"
#include "libpq/pqformat.h"
#include "utils/builtins.h"

PG_MODULE_MAGIC;

int	b64_pton(char const *, u_char *, size_t);
int	b64_ntop(u_char const *, size_t, char *, size_t);

/* ruid size in bytes */
#define RUID_LEN 16

/* pg_ruid_t is declared to be struct pg_uuid_t in uuid.h */
typedef struct pg_ruid_t
{
	unsigned char data[RUID_LEN];
} pg_ruid_t;

#define DatumGetRUIDP(X)	((pg_ruid_t *)DatumGetPointer(X))
#define PG_GETARG_RUID_P(X)	DatumGetRUIDP(PG_GETARG_DATUM(X))

#define RUIDPGetDatum(X)	PointerGetDatum(X)
#define PG_RETURN_RUID_P(X)	return RUIDPGetDatum(X)

static void	string_to_ruid(const char *, pg_ruid_t *);
static int	ruid_internal_cmp(const pg_ruid_t *, const pg_ruid_t *);

Datum ruid_in(PG_FUNCTION_ARGS);
Datum ruid_out(PG_FUNCTION_ARGS);
Datum ruid_recv(PG_FUNCTION_ARGS);
Datum ruid_send(PG_FUNCTION_ARGS);
Datum ruid_lt(PG_FUNCTION_ARGS);
Datum ruid_le(PG_FUNCTION_ARGS);
Datum ruid_eq(PG_FUNCTION_ARGS);
Datum ruid_ge(PG_FUNCTION_ARGS);
Datum ruid_gt(PG_FUNCTION_ARGS);
Datum ruid_ne(PG_FUNCTION_ARGS);
Datum ruid_cmp(PG_FUNCTION_ARGS);
Datum ruid_hash(PG_FUNCTION_ARGS);

PG_FUNCTION_INFO_V1(ruid_in);

Datum
ruid_in(PG_FUNCTION_ARGS)
{
	pg_ruid_t  *ruid;
	char	   *ruid_str = PG_GETARG_CSTRING(0);

	ruid = (pg_ruid_t *)palloc(sizeof(*ruid));

	string_to_ruid(ruid_str, ruid);

	PG_RETURN_RUID_P(ruid);
}

PG_FUNCTION_INFO_V1(ruid_out);

Datum
ruid_out(PG_FUNCTION_ARGS)
{
	StringInfoData	 buf;
	unsigned char	 in[18];
	unsigned int	 n = 0;
	pg_ruid_t	*ruid = PG_GETARG_RUID_P(0);
	char		 out[25];

	bzero(&out, sizeof(out));

	in[n] = '\0';
	while (++n < sizeof(in)-1)
		in[n] = ruid->data[n-1];
	in[n++] = '\0';


	/* encode uuid data in base64 */
	n = b64_ntop(in, sizeof(in), out, sizeof(out));

	initStringInfo(&buf);

	/* start before padding of the base64 string, walk backwards and
	 * replace special chars
	 */
	for (n = 1; n < sizeof(out)-2; n++)
		if (out[n] == '+')
			appendStringInfoChar(&buf, '-');
		else if (out[n] == '/')
			appendStringInfoChar(&buf, '_');
		else
			appendStringInfoChar(&buf, out[n]);

	PG_RETURN_CSTRING(buf.data);
}

/*
 * We allow RUIDs as a series of 32 hexadecimal digits with an optional dash
 * after each group of 4 hexadecimal digits, and optionally surrounded by {}.
 * (The canonical format 8x-4x-4x-4x-12x, where "nx" means n hexadecimal
 * digits, is the only one used for output.)
 */
static void
string_to_ruid(const char *string, pg_ruid_t *ruid)
{
	const char	*src = string;
	size_t		 len = strlen(string);
	bool		 braces = false;
	int		 i;

	/* get and check RUID length */
	if (len == 22) {
		unsigned char	 out[18];
		unsigned int	 n = 0;
		char		 buf[25];

		buf[n] = 'A';
		while (++n < sizeof(buf)-2)
			switch (src[n-1]) {
			case '-': buf[n] = '+'; break;
			case '_': buf[n] = '/'; break;
			default:
				if (!(isalpha(src[n-1]) || isdigit(src[n-1])))
					goto syntax_error;
				buf[n] = src[n-1];
			}
		buf[n++] = 'A';
		buf[n++] = '\0';

		bzero(&out, sizeof(out));

		if (b64_pton(buf, out, sizeof(out)) != sizeof(out))
			goto syntax_error;

		/* ignore the leading padding byte */
		memcpy(ruid->data, out+1, sizeof(ruid->data));

		return;
	}

	/* otherwise check for uuid syntax */

	if (src[0] == '{') {
		src++;
		braces = true;
	}

	for (i = 0; i < RUID_LEN; i++) {
		char		str_buf[3];

		if (src[0] == '\0' || src[1] == '\0')
			goto syntax_error;
		memcpy(str_buf, src, 2);
		if (!isxdigit((unsigned char) str_buf[0]) ||
			!isxdigit((unsigned char) str_buf[1]))
			goto syntax_error;

		str_buf[2] = '\0';
		ruid->data[i] = (unsigned char) strtoul(str_buf, NULL, 16);
		src += 2;
		if (src[0] == '-' && (i % 2) == 1 && i < RUID_LEN - 1)
			src++;
	}

	if (braces) {
		if (*src != '}')
			goto syntax_error;
		src++;
	}

	if (*src != '\0')
		goto syntax_error;

	return;

syntax_error:
	ereport(ERROR,
			(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
			 errmsg("invalid input syntax for ruid: \"%s\"",
					string)));
}

PG_FUNCTION_INFO_V1(ruid_recv);

Datum
ruid_recv(PG_FUNCTION_ARGS)
{
	StringInfo	 buffer = (StringInfo)PG_GETARG_POINTER(0);
	pg_ruid_t	*ruid;

	ruid = (pg_ruid_t *)palloc(RUID_LEN);

	memcpy(ruid->data, pq_getmsgbytes(buffer, RUID_LEN), RUID_LEN);

	PG_RETURN_POINTER(ruid);
}

PG_FUNCTION_INFO_V1(ruid_send);

Datum
ruid_send(PG_FUNCTION_ARGS)
{
	StringInfoData	 buffer;
	pg_ruid_t	*ruid = PG_GETARG_RUID_P(0);

	pq_begintypsend(&buffer);
	pq_sendbytes(&buffer, (char *)ruid->data, RUID_LEN);

	PG_RETURN_BYTEA_P(pq_endtypsend(&buffer));
}

/* internal ruid compare function */
static int
ruid_internal_cmp(const pg_ruid_t *arg1, const pg_ruid_t *arg2)
{
	return memcmp(arg1->data, arg2->data, RUID_LEN);
}

PG_FUNCTION_INFO_V1(ruid_lt);

Datum
ruid_lt(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*arg1 = PG_GETARG_RUID_P(0);
	pg_ruid_t	*arg2 = PG_GETARG_RUID_P(1);

	PG_RETURN_BOOL(ruid_internal_cmp(arg1, arg2) < 0);
}

PG_FUNCTION_INFO_V1(ruid_le);

Datum
ruid_le(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*arg1 = PG_GETARG_RUID_P(0);
	pg_ruid_t	*arg2 = PG_GETARG_RUID_P(1);

	PG_RETURN_BOOL(ruid_internal_cmp(arg1, arg2) <= 0);
}

PG_FUNCTION_INFO_V1(ruid_eq);

Datum
ruid_eq(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*arg1 = PG_GETARG_RUID_P(0);
	pg_ruid_t	*arg2 = PG_GETARG_RUID_P(1);

	PG_RETURN_BOOL(ruid_internal_cmp(arg1, arg2) == 0);
}

PG_FUNCTION_INFO_V1(ruid_ge);

Datum
ruid_ge(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*arg1 = PG_GETARG_RUID_P(0);
	pg_ruid_t	*arg2 = PG_GETARG_RUID_P(1);

	PG_RETURN_BOOL(ruid_internal_cmp(arg1, arg2) >= 0);
}

PG_FUNCTION_INFO_V1(ruid_gt);

Datum
ruid_gt(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*arg1 = PG_GETARG_RUID_P(0);
	pg_ruid_t	*arg2 = PG_GETARG_RUID_P(1);

	PG_RETURN_BOOL(ruid_internal_cmp(arg1, arg2) > 0);
}

PG_FUNCTION_INFO_V1(ruid_ne);

Datum
ruid_ne(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*arg1 = PG_GETARG_RUID_P(0);
	pg_ruid_t	*arg2 = PG_GETARG_RUID_P(1);

	PG_RETURN_BOOL(ruid_internal_cmp(arg1, arg2) != 0);
}

PG_FUNCTION_INFO_V1(ruid_cmp);

/* handler for btree index operator */
Datum
ruid_cmp(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*arg1 = PG_GETARG_RUID_P(0);
	pg_ruid_t	*arg2 = PG_GETARG_RUID_P(1);

	PG_RETURN_INT32(ruid_internal_cmp(arg1, arg2));
}

PG_FUNCTION_INFO_V1(ruid_hash);

/* hash index support */
Datum
ruid_hash(PG_FUNCTION_ARGS)
{
	pg_ruid_t	*key = PG_GETARG_RUID_P(0);

	PG_RETURN_INT32(hash_any(key->data, RUID_LEN));
}

