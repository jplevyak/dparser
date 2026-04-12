/*
 Copyright 1994-2004 John Plevyak, All Rights Reserved
*/
#include "d.h"

static char *SPACES = "                                                                               ";
static char *arg_types_keys = (char *)"ISDfF+TL";
static char *arg_types_desc[] = {(char *)"int     ", (char *)"string  ", (char *)"double  ",
                                 (char *)"set off ", (char *)"set on  ", (char *)"incr    ",
                                 (char *)"toggle  ", (char *)"int64   ", (char *)"        "};

static void process_arg(ArgumentState *arg_state, int i, char **arg_val, char ***argv) {
  char *arg = NULL;
  ArgumentDescription *desc = arg_state->desc;
  if (desc[i].type) {
    char type = desc[i].type[0];
    if (type == 'F' || type == 'f')
      *(int *)desc[i].location = type == 'F' ? 1 : 0;
    else if (type == 'T')
      *(int *)desc[i].location = !*(int *)desc[i].location;
    else if (type == '+')
      (*(int *)desc[i].location)++;
    else {
      arg = *arg_val;
      if (!arg) {
        *argv = *argv + 1;
        arg = **argv;
        if (!arg) usage(arg_state, NULL);
      }
      switch (type) {
        case 'I':
          *(int *)desc[i].location = strtol(arg, NULL, 0);
          break;
        case 'D':
          *(double *)desc[i].location = strtod(arg, NULL);
          break;
        case 'L':
          *(int64 *)desc[i].location = strtoll(arg, NULL, 0);
          break;
        case 'S': {
          int limit = atoi(desc[i].type + 1);
          strncpy((char *)desc[i].location, arg, limit);
          if (limit > 0) ((char *)desc[i].location)[limit - 1] = 0;
          break;
        }
        default:
          fprintf(stderr, "%s:bad argument description\n", arg_state->program_name);
          exit(1);
          break;
      }
      *arg_val = NULL; /* mark consumed */
    }
  }
  if (desc[i].pfn) desc[i].pfn(arg_state, arg);
}

void process_args(ArgumentState *arg_state, char **argv) {
  int i = 0, len;
  ArgumentDescription *desc = arg_state->desc;
  /* Grab Environment Variables */
  for (i = 0;; i++) {
    if (!desc[i].name) break;
    if (desc[i].env) {
      char type = desc[i].type[0];
      char *env = getenv(desc[i].env);
      if (!env) continue;
      switch (type) {
        case 'A':
        case 'f':
        case 'F':
          break;
        case 'I':
          *(int *)desc[i].location = strtol(env, NULL, 0);
          break;
        case 'D':
          *(double *)desc[i].location = strtod(env, NULL);
          break;
        case 'L':
          *(int64 *)desc[i].location = strtoll(env, NULL, 0);
          break;
        case 'S': {
          int limit = strtol(desc[i].type + 1, NULL, 0);
          strncpy((char *)desc[i].location, env, limit);
          if (limit > 0) ((char *)desc[i].location)[limit - 1] = 0;
          break;
        }
      }
      if (desc[i].pfn) desc[i].pfn(arg_state, env);
    }
  }

  /*
    Grab Command Line Arguments
  */
  arg_state->program_name = argv[0];
  if (!*argv) return;
  argv++;
  while (*argv) {
    char *arg = *argv;
    if (!strcmp(arg, "--")) {
      argv++;
      while (*argv) {
        arg_state->file_argument =
            (char **)REALLOC(arg_state->file_argument, sizeof(char **) * (arg_state->nfile_arguments + 2));
        arg_state->file_argument[arg_state->nfile_arguments++] = *argv;
        arg_state->file_argument[arg_state->nfile_arguments] = NULL;
        argv++;
      }
      break;
    } else if (arg[0] == '-' && arg[1] == '-') {
      char *key = arg + 2;
      char *val = strchr(key, '=');
      if (val) {
        len = val - key;
        val++;
      } else {
        len = strlen(key);
      }
      int matched = 0;
      for (i = 0;; i++) {
        if (!desc[i].name) break;
        if (len == (int)strlen(desc[i].name) && !strncmp(desc[i].name, key, len)) {
          matched = 1;
          char *pass_val = val;
          process_arg(arg_state, i, &pass_val, &argv);
          break;
        }
      }
      if (!matched) usage(arg_state, NULL);
      if (*argv) argv++;
    } else if (arg[0] == '-' && arg[1] != '\0') {
      char *p = arg + 1;
      while (*p) {
        int matched = 0;
        for (i = 0;; i++) {
          if (!desc[i].name) break;
          if (desc[i].key == *p) {
            matched = 1;
            p++;
            char *pass_val = *p ? p : NULL;
            process_arg(arg_state, i, &pass_val, &argv);
            if (pass_val == NULL) {
              p = ""; /* value consumed, break inner loop */
            }
            break;
          }
        }
        if (!matched) usage(arg_state, NULL);
      }
      if (*argv) argv++;
    } else {
      arg_state->file_argument =
          (char **)REALLOC(arg_state->file_argument, sizeof(char **) * (arg_state->nfile_arguments + 2));
      arg_state->file_argument[arg_state->nfile_arguments++] = arg;
      arg_state->file_argument[arg_state->nfile_arguments] = NULL;
      argv++;
    }
  }
}

void usage(ArgumentState *arg_state, char *arg_unused) {
  ArgumentDescription *desc = arg_state->desc;
  int i;

  (void)arg_unused;
  fprintf(stderr, "Usage: %s [flags|args]\n", arg_state->program_name);
  for (i = 0;; i++) {
    if (!desc[i].name) break;
    if (!desc[i].description) continue;
    int type_idx = strlen(arg_types_keys);
    if (desc[i].type) {
      char *p = strchr(arg_types_keys, desc[i].type[0]);
      if (p) type_idx = p - arg_types_keys;
    }
    fprintf(stderr, "  %c%c%c --%s%s%s", desc[i].key != ' ' ? '-' : ' ', desc[i].key, desc[i].key != ' ' ? ',' : ' ',
            desc[i].name, (strlen(desc[i].name) + 61 < 81) ? &SPACES[strlen(desc[i].name) + 61] : "",
            arg_types_desc[type_idx]);
    switch (desc[i].type ? desc[i].type[0] : 0) {
      case 0:
        fprintf(stderr, "          ");
        break;
      case 'L':
        fprintf(stderr,
#if defined(__alpha)
                " %-9ld",
#else
#if defined(FreeBSD)
                " %-9qd",
#else
                " %-9" PRId64,
#endif
#endif
                *(int64 *)desc[i].location);
        break;
      case 'S':
        if (*(char *)desc[i].location) {
          if (strlen((char *)desc[i].location) < 10)
            fprintf(stderr, " %-9s", (char *)desc[i].location);
          else {
            char temp[8];
            strncpy(temp, (char *)desc[i].location, 7);
            temp[7] = 0;
            fprintf(stderr, " %-7s..", temp);
          }
        } else
          fprintf(stderr, " (null)   ");
        break;
      case 'D':
        fprintf(stderr, " %-9.3e", *(double *)desc[i].location);
        break;
      case '+':
      case 'I':
        fprintf(stderr, " %-9d", *(int *)desc[i].location);
        break;
      case 'T':
      case 'f':
      case 'F':
        fprintf(stderr, " %-9s", *(int *)desc[i].location ? "true " : "false");
        break;
    }
    fprintf(stderr, " %s\n", desc[i].description);
  }
  exit(1);
}

void free_args(ArgumentState *arg_state) {
  if (arg_state->file_argument) FREE(arg_state->file_argument);
}
