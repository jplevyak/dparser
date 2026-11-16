/*
  dparse() must not read past buf_len: the input need not be NUL-terminated.
  Each input is copied to the very end of a page that is followed by an
  inaccessible page, so any read past the end crashes.
*/
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include "dparse.h"

extern D_ParserTables parser_tables_gram;

static char *guarded(const char *text, size_t len) {
  long page = sysconf(_SC_PAGESIZE);
  char *mem = mmap(NULL, 2 * page, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (mem == MAP_FAILED) return NULL;
  mprotect(mem + page, page, PROT_NONE);
  char *buf = mem + page - len;
  memcpy(buf, text, len);
  return buf;
}

static void quiet(D_Parser *p) { (void)p; }

static int check(const char *name, const char *text, int expect_ok) {
  size_t len = strlen(text);
  char *buf = guarded(text, len);
  if (!buf) return 1;
  D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
  p->syntax_error_fn = quiet;
  D_ParseNode *pn = dparse(p, buf, (int)len);
  int ok = pn && !p->syntax_errors;
  if (pn) free_D_ParseNode(p, pn);
  free_D_Parser(p);
  printf("%-28s %s\n", name, ok == expect_ok ? "ok" : "FAILED");
  return ok != expect_ok;
}

int main(void) {
  int failed = 0;
  failed += check("token at end of buffer", "a + bc;", 1);
  failed += check("identifier at end", "a + bc", 0);       /* missing ';' */
  failed += check("line comment at end", "a; // comment", 1);
  failed += check("block comment at end", "a; /* comment", 1);
  failed += check("whitespace at end", "a;   \n  ", 1);
  failed += check("#line directive at end", "a;\n# 12", 1);
  failed += check("error recovery search", "a + + b", 0);  /* searches for ';' */
  /* A prefix of a longer string: the parse must stop at buf_len. */
  {
    const char *text = "a + b;xyz";
    D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
    p->syntax_error_fn = quiet;
    D_ParseNode *pn = dparse(p, (char *)text, 6);
    int ok = pn && !p->syntax_errors;
    if (pn) free_D_ParseNode(p, pn);
    free_D_Parser(p);
    printf("%-28s %s\n", "prefix of a longer string", ok ? "ok" : "FAILED");
    failed += !ok;
  }
  printf(failed ? "%d bounds test(s) FAILED\n" : "all bounds tests passed\n", failed);
  return failed != 0;
}
