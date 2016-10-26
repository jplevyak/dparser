/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/
#ifndef MKDPARSE_H
#define MKDPARSE_H

#if defined(__cplusplus)
extern "C" {
#endif

#include <stdlib.h>

struct Grammar;

void mkdparse(struct Grammar* g, char* grammar_pathname);
void mkdparse_from_string(struct Grammar* g, char* str);

#if defined(__cplusplus)
}
#endif

#endif  // MKDPARSE_H
