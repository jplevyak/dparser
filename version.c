/*
  $Id$
  
  $Log$

  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#include "d.h"

void
d_version(char *v) {
  v += sprintf(v, "%d.%d.%d", DPARSER_VERSION_MAJOR, DPARSER_VERSION_MINOR, DPARSER_ALPHA_VERSION);
}

