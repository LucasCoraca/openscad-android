/*
 * The gettext API OpenSCAD uses, for Android (bionic has no libintl): GNU .mo catalogs looked up from
 * bindtextdomain()'s folder and the language in LANGUAGE / LC_ALL / LC_MESSAGES / LANG, with Plural-Forms.
 * Catalogs are assumed to be UTF-8 (OpenSCAD's are); bind_textdomain_codeset() is accepted and ignored.
 */
#pragma once

#include <locale.h>

#ifdef __cplusplus
extern "C" {
#endif

char *gettext(const char *msgid);
char *dgettext(const char *domain, const char *msgid);
char *dcgettext(const char *domain, const char *msgid, int category);
char *ngettext(const char *msgid, const char *msgid_plural, unsigned long n);
char *dngettext(const char *domain, const char *msgid, const char *msgid_plural, unsigned long n);
char *dcngettext(const char *domain, const char *msgid, const char *msgid_plural, unsigned long n, int category);
char *textdomain(const char *domainname);
char *bindtextdomain(const char *domainname, const char *dirname);
char *bind_textdomain_codeset(const char *domainname, const char *codeset);

#ifdef __cplusplus
}
#endif
