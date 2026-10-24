/* GLib's UTF-8 functions used by OpenSCAD (see glib.h), following gutf8.c from GLib 2.x. */
#include "glib.h"

#include <stdlib.h>
#include <string.h>
#include <utf8proc.h>

static const gchar utf8_skip_data[256] = {
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 1, 1
};
const gchar *const g_utf8_skip = utf8_skip_data;

gunichar g_utf8_get_char(const gchar *p)
{
  const unsigned char *s = (const unsigned char *)p;
  unsigned char c = s[0];
  int len;
  gunichar r;
  if (c < 0x80) return c;
  else if ((c & 0xe0) == 0xc0) { len = 2; r = c & 0x1f; }
  else if ((c & 0xf0) == 0xe0) { len = 3; r = c & 0x0f; }
  else if ((c & 0xf8) == 0xf0) { len = 4; r = c & 0x07; }
  else if ((c & 0xfc) == 0xf8) { len = 5; r = c & 0x03; }
  else if ((c & 0xfe) == 0xfc) { len = 6; r = c & 0x01; }
  else return (gunichar)-1;
  for (int i = 1; i < len; i++) {
    if ((s[i] & 0xc0) != 0x80) return (gunichar)-1;
    r = (r << 6) | (s[i] & 0x3f);
  }
  return r;
}

gboolean g_unichar_validate(gunichar ch)
{
  return ch < 0x110000 && (ch & 0xfffff800) != 0xd800;
}

/* Strict validation as in GLib: no overlong forms, surrogates or code points above U+10FFFF.
   max_len < 0 means NUL terminated; otherwise embedded NULs are invalid. */
gboolean g_utf8_validate(const gchar *str, gssize max_len, const gchar **end)
{
  const unsigned char *p = (const unsigned char *)str;
  const unsigned char *stop = max_len < 0 ? NULL : p + max_len;
  gboolean ok = 1;
  while (stop ? p < stop : *p) {
    unsigned char c = *p;
    if (c == 0) { ok = 0; break; }
    if (c < 0x80) { p++; continue; }
    int len;
    gunichar min, v;
    if ((c & 0xe0) == 0xc0) { len = 2; min = 0x80; v = c & 0x1f; }
    else if ((c & 0xf0) == 0xe0) { len = 3; min = 0x800; v = c & 0x0f; }
    else if ((c & 0xf8) == 0xf0) { len = 4; min = 0x10000; v = c & 0x07; }
    else { ok = 0; break; }
    if (stop && stop - p < len) { ok = 0; break; }
    int i;
    for (i = 1; i < len; i++) {
      if ((p[i] & 0xc0) != 0x80) break;
      v = (v << 6) | (p[i] & 0x3f);
    }
    if (i < len || v < min || !g_unichar_validate(v)) { ok = 0; break; }
    p += len;
  }
  if (end) *end = (const gchar *)p;
  return ok;
}

gint g_unichar_to_utf8(gunichar c, gchar *outbuf)
{
  int first, len;
  if (c < 0x80) { first = 0; len = 1; }
  else if (c < 0x800) { first = 0xc0; len = 2; }
  else if (c < 0x10000) { first = 0xe0; len = 3; }
  else if (c < 0x200000) { first = 0xf0; len = 4; }
  else if (c < 0x4000000) { first = 0xf8; len = 5; }
  else { first = 0xfc; len = 6; }
  if (outbuf) {
    for (int i = len - 1; i > 0; --i) {
      outbuf[i] = (gchar)((c & 0x3f) | 0x80);
      c >>= 6;
    }
    outbuf[0] = (gchar)(c | first);
  }
  return len;
}

glong g_utf8_strlen(const gchar *p, gssize max)
{
  glong len = 0;
  const gchar *start = p;
  if (!p || max == 0) return 0;
  if (max < 0) {
    while (*p) { p = g_utf8_next_char(p); ++len; }
  } else {
    p = g_utf8_next_char(p);
    while (p - start < max && *start) { ++len; start = p; p = g_utf8_next_char(p); }
    if (p - start <= max && *start) ++len;  /* the last character fits completely */
  }
  return len;
}

gchar *g_utf8_offset_to_pointer(const gchar *str, glong offset)
{
  const gchar *s = str;
  if (offset > 0) {
    while (offset--) s = g_utf8_next_char(s);
  } else {
    while (offset) {  /* back over continuation bytes */
      const gchar *s1 = s;
      s += offset;
      while ((*s & 0xc0) == 0x80) s--;
      offset += g_utf8_strlen(s, s1 - s);
    }
  }
  return (gchar *)s;
}

gchar *g_utf8_strncpy(gchar *dest, const gchar *src, size_t n)
{
  const gchar *s = src;
  while (n && *s) { s = g_utf8_next_char(s); n--; }
  strncpy(dest, src, s - src);
  dest[s - src] = 0;
  return dest;
}

gchar *g_utf8_normalize(const gchar *str, gssize len, GNormalizeMode mode)
{
  utf8proc_option_t opt = UTF8PROC_STABLE;
  switch (mode) {
  case G_NORMALIZE_DEFAULT: opt |= UTF8PROC_DECOMPOSE; break;
  case G_NORMALIZE_DEFAULT_COMPOSE: opt |= UTF8PROC_COMPOSE; break;
  case G_NORMALIZE_ALL: opt |= UTF8PROC_DECOMPOSE | UTF8PROC_COMPAT; break;
  case G_NORMALIZE_ALL_COMPOSE: opt |= UTF8PROC_COMPOSE | UTF8PROC_COMPAT; break;
  }
  if (len < 0) {
    len = (gssize)strlen(str);
  } else {
    const void *nul = memchr(str, 0, (size_t)len);  /* GLib stops at a NUL inside len too */
    if (nul) len = (const gchar *)nul - str;
  }
  utf8proc_uint8_t *out = NULL;
  if (utf8proc_map((const utf8proc_uint8_t *)str, len, &out, opt) < 0) return NULL;
  return (gchar *)out;  /* malloc'ed by utf8proc, released with g_free */
}

void g_free(gpointer mem)
{
  free(mem);
}
