/* d_config.h.  Generated from d_config.h.in by configure.  */
/* d_config.h.in.  Generated from configure.ac by autoheader.  */

/* The alpha version number, if applicable. */
#define DPARSER_ALPHA_VERSION 2

/* The major version number of this release. */
#define DPARSER_VERSION_MAJOR 1

/* The minor version number of this release. */
#define DPARSER_VERSION_MINOR 14

/* dparser general debugging flag. */
#define D_DEBUG 1

/* is the package version mark. */
#define D_VERSION "(DPARSER_VERSION_MAJOR<<24)+(DPARSER_VERSION_MINOR<<16)+(DPARSER_ALPHA_VERSION & 15)"

/* Define to 1 if you have the `bzero' function. */
#define HAVE_BZERO 1

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define to 1 if you have the <fcntl.h> header file. */
#define HAVE_FCNTL_H 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the <limits.h> header file. */
#define HAVE_LIMITS_H 1

/* Define to 1 if your system has a GNU libc compatible `malloc' function, and
   to 0 otherwise. */
#define HAVE_MALLOC 1

/* Define to 1 if you have the `memmove' function. */
#define HAVE_MEMMOVE 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have the `memset' function. */
#define HAVE_MEMSET 1

/* Define to 1 if you have the <memwatch.h> header file. */
/* #undef HAVE_MEMWATCH_H */

/* Define to 1 if your system has a GNU libc compatible `realloc' function,
   and to 0 otherwise. */
#define HAVE_REALLOC 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the `strchr' function. */
#define HAVE_STRCHR 1

/* Define to 1 if you have the `strerror' function. */
#define HAVE_STRERROR 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the `strncasecmp' function. */
#define HAVE_STRNCASECMP 1

/* Define to 1 if you have the `strrchr' function. */
#define HAVE_STRRCHR 1

/* Define to 1 if you have the `strstr' function. */
#define HAVE_STRSTR 1

/* Define to 1 if you have the `strtol' function. */
#define HAVE_STRTOL 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/time.h> header file. */
#define HAVE_SYS_TIME_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* leak detection mode, but needs "leak" to work. */
/* #undef LEAK_DETECT */

/* Define to the sub-directory in which libtool stores uninstalled libraries.
   */
#define LT_OBJDIR ".libs/"

/* Define to 1 if your C compiler doesn't accept -c and -o together. */
/* #undef NO_MINUS_C_MINUS_O */

/* Name of package */
#define PACKAGE "dparser"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "john.plevyak@yahoo.com"

/* Define to the full name of this package. */
#define PACKAGE_NAME "dparser"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "dparser 1.14.2"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "dparser"

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Define to the version of this package. */
#define PACKAGE_VERSION "1.14.2"

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* we are using the state of art, sofisticated Garbage Collector. */
#define USE_GC 1

/* Version number of package */
#define VERSION "1.14.2"

/* Define if using the dmalloc debugging malloc package */
/* #undef WITH_DMALLOC */

/* Define to rpl_malloc if the replacement function should be used. */
/* #undef malloc */

/* Define to rpl_realloc if the replacement function should be used. */
/* #undef realloc */

/* Define to `unsigned int' if <sys/types.h> does not define. */
/* #undef size_t */
