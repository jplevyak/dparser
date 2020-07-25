/*
 Copyright 2002-2004 John Plevyak, All Rights Reserved
*/
#include "d.h"

const char *git_commit_id = "$Id$";

void d_version(char *v) {
  v += sprintf(v, "%d.%d", D_MAJOR_VERSION, D_MINOR_VERSION);
  if (strlen(git_commit_id) > 4) {
    char scommit[43];
    strcpy(scommit, &git_commit_id[5]);
    scommit[40] = 0;
    v += sprintf(v, ".%s", scommit);
  }
}
