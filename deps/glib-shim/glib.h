/*
 * The part of GLib's UTF-8 API that OpenSCAD uses (str_utf8_wrapper.h, UnicodeIdentifier.cc, Value.cc,
 * FreetypeRenderer.cc, LibraryInfo.cc), so the Android build does not need all of GLib.
 * Same semantics as GLib 2.x; NFC normalization comes from utf8proc.
 */
#pragma once
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#define GLIB_MAJOR_VERSION 2
#define GLIB_MINOR_VERSION 80
#define GLIB_MICRO_VERSION 0
#define GLIB_SHIM 1

#ifdef __cplusplus
extern "C" {
#endif

typedef char gchar;
typedef int gint;
typedef int gboolean;
typedef uint32_t gunichar;
typedef ssize_t gssize;
typedef long glong;
typedef void *gpointer;

typedef enum { G_NORMALIZE_DEFAULT, G_NORMALIZE_NFD = G_NORMALIZE_DEFAULT, G_NORMALIZE_DEFAULT_COMPOSE,
               G_NORMALIZE_NFC = G_NORMALIZE_DEFAULT_COMPOSE, G_NORMALIZE_ALL, G_NORMALIZE_NFKD = G_NORMALIZE_ALL,
               G_NORMALIZE_ALL_COMPOSE, G_NORMALIZE_NFKC = G_NORMALIZE_ALL_COMPOSE } GNormalizeMode;

extern const gchar *const g_utf8_skip;
#define g_utf8_next_char(p) (char *)((p) + g_utf8_skip[*(const unsigned char *)(p)])

gunichar g_utf8_get_char(const gchar *p);
gboolean g_utf8_validate(const gchar *str, gssize max_len, const gchar **end);
gboolean g_unichar_validate(gunichar ch);
gint g_unichar_to_utf8(gunichar c, gchar *outbuf);
glong g_utf8_strlen(const gchar *p, gssize max);
gchar *g_utf8_offset_to_pointer(const gchar *str, glong offset);
gchar *g_utf8_strncpy(gchar *dest, const gchar *src, size_t n);
gchar *g_utf8_normalize(const gchar *str, gssize len, GNormalizeMode mode);
void g_free(gpointer mem);

#ifdef __cplusplus
}
#endif
