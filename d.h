/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/
#ifndef _d_H_
#define _d_H_

#define __USE_MINGW_ANSI_STDIO 1
#ifdef MEMWATCH
#define MEMWATCH_STDIO 1
#include "../../src/memwatch-2.67/memwatch.h"
#define MEM_GROW_MACRO
#endif
#include <assert.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#if !defined(__FreeBSD__) || (__FreeBSD_version >= 500000)
#include <inttypes.h>
#endif
#include <limits.h>
#include <sys/types.h>
#if !defined(__MINGW32__) && !defined(WIN32)
#include <sys/mman.h>
#include <sys/uio.h>
#endif
#if !defined(WIN32)
#include <unistd.h>
#include <sys/time.h>
#include <dirent.h>
#endif
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <ctype.h>
#include <string.h>
#if !defined(__MINGW32__) && !defined(WIN32)
#include <strings.h>
#endif

#ifdef LEAK_DETECT
#define GC_DEBUG
#include "gc.h"
#define MALLOC(n) GC_MALLOC(n)
#define CALLOC(m, n) GC_MALLOC((m) * (n))
#define FREE(p) GC_FREE(p)
#define REALLOC(p, n) GC_REALLOC((p), (n))
#define CHECK_LEAKS() GC_gcollect()
#else
#ifdef USE_GC
#include "gc.h"
#define MALLOC GC_MALLOC
#define REALLOC GC_REALLOC
#define FREE(_x)
#define malloc dont_use_malloc_use_MALLOC_instead
#define relloc dont_use_realloc_use_REALLOC_instead
#define free dont_use_free_use_FREE_instead
#else
#define MALLOC malloc
#define REALLOC realloc
#define FREE free
#endif
#endif

/* enough already with the signed/unsiged char issues
 */
#define isspace_(_c) isspace((unsigned char)(_c))
#define isdigit_(_c) isdigit((unsigned char)(_c))
#define isxdigit_(_c) isxdigit((unsigned char)(_c))
#define isprint_(_c) isprint((unsigned char)(_c))

/* Compilation Options
 */

#define round2(_x, _n) ((_x + ((_n)-1)) & ~((_n)-1))
#define tohex1(_x) ((((_x)&15) > 9) ? (((_x)&15) - 10 + 'A') : (((_x)&15) + '0'))
#define tohex2(_x) ((((_x) >> 4) > 9) ? (((_x) >> 4) - 10 + 'A') : (((_x) >> 4) + '0'))
#define numberof(_x) ((sizeof(_x)) / (sizeof((_x)[0])))

typedef int8_t int8;
typedef uint8_t uint8;
typedef int32_t int32;
typedef uint32_t uint32;
typedef int64_t int64;
typedef uint64_t uint64;
typedef int16_t int16;
typedef uint16_t uint16;
typedef unsigned int uint;

#ifdef D_DEBUG
#define DBG(_x)            \
  if (d_debug_level > 1) { \
    _x;                    \
  }
#else
#define DBG(_x)
#endif

#include "dparse.h"
#include "arg.h"
#include "util.h"
#include "gram.h"
#include "lr.h"
#include "lex.h"
#include "scan.h"
#include "parse.h"
#include "write_tables.h"
#include "read_binary.h"

void d_version(char *);

#endif
