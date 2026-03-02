#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include "dparse.h"

extern D_ParserTables parser_tables_gram;

int main(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
    return 1;
  }

  FILE *f = fopen(argv[1], "rb");
  if (!f) {
    perror("fopen");
    return 1;
  }

  fseek(f, 0, SEEK_END);
  long fsize = ftell(f);
  fseek(f, 0, SEEK_SET);

  char *buf = malloc(fsize + 1);
  if (!buf) {
    perror("malloc");
    return 1;
  }

  if (fread(buf, 1, fsize, f) != fsize) {
    fprintf(stderr, "Failed to read file\n");
    free(buf);
    return 1;
  }
  buf[fsize] = 0;
  fclose(f);

  D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
  p->save_parse_tree = 1;
  p->loc.pathname = argv[1];

  if (dparse(p, buf, fsize) && !p->syntax_errors) {
    printf("Parse successful\n");
  } else {
    printf("Parse failed\n");
    free_D_Parser(p);
    free(buf);
    return 1;
  }

  free_D_Parser(p);
  free(buf);
  return 0;
}
