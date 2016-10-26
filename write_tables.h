/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#ifndef WRITE_TABLES_H
#define WRITE_TABLES_H

#ifdef __cplusplus
extern "C" {
#endif

int write_c_tables(Grammar* g);
int write_binary_tables(Grammar* g);
int write_binary_tables_to_file(Grammar* g, FILE* fp);
int write_binary_tables_to_string(Grammar* g,
                                  unsigned char** str,
                                  unsigned int* str_len);

#ifdef __cplusplus
}
#endif

#endif  // WRITE_TABLES_H
