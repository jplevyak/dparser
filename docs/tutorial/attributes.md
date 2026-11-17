# 7. Attributes after Parsing

Actions compute values bottom up: each node's value comes from its
children's. Much of what a compiler needs after parsing also flows the
other way. Which variables are in scope here? What type is expected? A
pass can push that information down by hand, but then you must order
the passes yourself.

*Attributes* do this declaratively. You write an equation for each
attribute, and DParser evaluates the attributes you ask for, in whatever
order their dependencies require:

- a **synthesized** attribute is computed from a node and its children,
  like a value from an action: the *type* of `x + 1`;
- an **inherited** attribute is given to a node by its parent: the
  *environment* (the variables in scope) of an expression.

This chapter type-checks a tiny language. A block declares variables,
visible everywhere inside it, including nested blocks.

## The grammar

`types.g` has no actions at all:

```c
program: block ;
block: '{' decl* stmt* '}' ;
decl: 'var' name ':' tname ';' ;
stmt: expr ';' | block ;
expr: expr '+' expr $left 10
    | expr '==' expr $left 5
    | name
    | number ;
tname: 'int' | 'bool' ;
name: "[a-z]+" $term -1 ;
number: "[0-9]+" ;
```

Build it with `-H 1`, which writes `types.g.d_parser.h`. Besides the
usual contents, the header has a constant for each rule:
`D_RULE_expr_0` is the first rule of `expr` (`expr '+' expr`),
`D_RULE_expr_1` the second, and so on.

```bash
make_dparser -H 1 types.g
```

## The equations

An attribute is a `D_Attr`: a name, its kind, an equation function, and
the size of its values. The library stores each value, so the equation
writes it to `out`.

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "dattr.h"
#include "types.g.d_parser.h"

extern D_ParserTables parser_tables_gram;

/* An environment: the variables in scope, as a linked list. */
typedef struct Var {
  const char *name, *type;
  int len;
  struct Var *next;
} Var;

static D_Attr env, type;

static const char *name_of(D_AttrTree *t, D_AttrNode *n) { return d_attr_symbol_name(t, n); }

/* Add the declarations under n (but not in nested blocks) to *e. */
static void declare(D_AttrTree *t, D_AttrNode *n, Var **e) {
  if (!strcmp(name_of(t, n), "block")) return;
  if (!strcmp(name_of(t, n), "decl")) {
    D_ParseNode *id = d_attr_parse_node(d_attr_child(n, 1));
    D_ParseNode *ty = d_attr_parse_node(d_attr_child(n, 3));
    Var *v = malloc(sizeof(Var));
    v->name = id->start_loc.s;
    v->len = (int)(id->end - id->start_loc.s);
    v->type = *ty->start_loc.s == 'i' ? "int" : "bool";
    v->next = *e;
    *e = v; /* never freed, to keep the example short */
    return;
  }
  for (int i = 0; i < d_attr_n_children(n); i++) declare(t, d_attr_child(n, i), e);
}

/* env, inherited: empty at the root; a block gives its children its own
   env plus its declarations; every other node passes its env down. */
static int eval_env(D_AttrTree *t, D_Attr *a, D_AttrNode *node, int child, void *out) {
  Var **e = out;
  if (child < 0) return 1;                                  /* the root: empty */
  if (strcmp(name_of(t, node), "block")) return 0;          /* copy down */
  *e = *(Var **)d_attr_get(t, node, a);
  for (int i = 0; i < d_attr_n_children(node); i++) declare(t, d_attr_child(node, i), e);
  return 1;
}

static const char *type_of(D_AttrTree *t, D_AttrNode *n) {
  const char **v = d_attr_get(t, n, &type);
  return v ? *v : "?";
}

/* type, synthesized: of expressions, names and numbers. */
static int eval_type(D_AttrTree *t, D_Attr *a, D_AttrNode *node, int child, void *out) {
  const char **ty = out, *sym = name_of(t, node);
  (void)a, (void)child;
  if (!strcmp(sym, "number")) {
    *ty = "int";
  } else if (!strcmp(sym, "name")) {
    D_ParseNode *pn = d_attr_parse_node(node);
    Var *v = *(Var **)d_attr_get(t, node, &env);
    while (v && (v->len != pn->end - pn->start_loc.s || strncmp(v->name, pn->start_loc.s, v->len))) v = v->next;
    *ty = v ? v->type : "undeclared";
  } else if (!strcmp(sym, "expr")) {
    int rule = d_attr_production(node);
    if (rule == D_RULE_expr_0 || rule == D_RULE_expr_1) {
      const char *l = type_of(t, d_attr_child(node, 0)), *r = type_of(t, d_attr_child(node, 2));
      if (rule == D_RULE_expr_0)
        *ty = !strcmp(l, "int") && !strcmp(r, "int") ? "int" : "error";
      else
        *ty = !strcmp(l, r) ? "bool" : "error";
    } else
      *ty = type_of(t, d_attr_child(node, 0)); /* name or number */
  } else
    return 0; /* no type */
  return 1;
}

static D_Attr env = {"env", D_ATTR_INH, eval_env, sizeof(Var *), NULL, NULL};
static D_Attr type = {"type", D_ATTR_SYN, eval_type, sizeof(const char *), NULL, NULL};

/* Print the type of each statement's expression. */
static void report(D_AttrTree *t, D_AttrNode *n) {
  if (!strcmp(name_of(t, n), "stmt") && !strcmp(name_of(t, d_attr_child(n, 0)), "expr")) {
    D_ParseNode *pn = d_attr_parse_node(n);
    printf("line %d: %.*s: %s\n", pn->start_loc.line, (int)(pn->end - pn->start_loc.s - 1), pn->start_loc.s,
           type_of(t, d_attr_child(n, 0)));
  }
  for (int i = 0; i < d_attr_n_children(n); i++) report(t, d_attr_child(n, i));
}

int main(int argc, char *argv[]) {
  D_Parser *p = new_D_Parser(&parser_tables_gram, 0);
  p->save_parse_tree = 1;
  D_ParseNode *pn = dparse(p, argv[1], (int)strlen(argv[1]));
  if (!pn || p->syntax_errors) return 1;
  D_Attr *attrs[] = {&env, &type};
  D_AttrTree *t = d_attr_tree(p, pn, attrs, 2, NULL);
  report(t, d_attr_root(t));
  d_attr_tree_free(t);
  free_D_ParseNode(p, pn);
  free_D_Parser(p);
  return 0;
}
```

The equations:

- **`env` is inherited.** Its equation is asked what a node gives to its
  child number `child`. Only `block` has an answer: its own environment
  plus its declarations. Every other node returns 0, meaning *no
  equation here*, and the child gets its parent's environment. This
  *copy-down* rule is why one equation, at `block`, is enough for every
  node inside it. At the root, the equation is called with `child` -1
  for the root's own value: an empty environment.
- **`type` is synthesized.** It switches on the node's symbol, and for
  `expr` on the rule that built it, `d_attr_production(node)`, which is
  compared with the `D_RULE_` constants. A name looks itself up in its
  own `env`, which asks its parent, and so on up to the nearest block.
- **`d_attr_get(t, node, attr)`** evaluates an attribute the first time
  it is asked for, and caches it. It returns NULL for an undefined value,
  such as the type of a node with no `type` equation.

The library works on the saved parse tree, so `save_parse_tree` must be
on. `d_attr_tree` copies the tree into nodes with parent links.

!!! note "Rules that share a number"
    The last two rules of `expr`, `name` and `number`, have the same length
    and no actions, so `make_dparser` builds them as one reduction, and
    `D_RULE_expr_2` equals `D_RULE_expr_3`. The child's symbol tells them
    apart, which is what `type_of(t, d_attr_child(node, 0))` relies on.

## Running it

```bash
cc -o check check.c types.g.d_parser.c -ldparse
./check '{ var x : int; var b : bool;
  x + 1;
  { var y : int; y == x; b + y; }
  z;
}'
```

```text
line 2: x + 1: int
line 3: y == x: bool
line 3: b + y: error
line 4: z: undeclared
```

`y == x` sees both `y`, declared in the inner block, and `x`, from the
outer one.

## Cycles

If an attribute's value depends on itself, for example a synthesized
attribute that asks for an inherited one that asks for the first,
`d_attr_get` reports the cycle on stderr with the chain of attributes
and nodes, and returns NULL for the request that closed it.
`d_attr_cycles(t)` counts the cycles found, and `d_attr_set_cycle_fn`
replaces the report.

## In C++, Python and Rust

The same evaluator is available in every binding:

- **C++**: `dattr.hpp`, with equations as lambdas returning
  `std::optional<T>`.
- **Python**: `parse(text, keep_tree=True)` keeps the tree, and the
  `dparser_attrs` module provides `@syn` and `@inh`.
- **Rust**: `dparser::attrs`, with `const` attributes.

See the [Attributes reference](../reference/attributes.md) for all of them.

## What you learned

- Synthesized attributes flow up and inherited attributes flow down; both
  are computed on demand and cached.
- An inherited equation that returns "no equation" copies its parent's
  value down, so one equation at a block reaches every node inside it.
- `d_attr_production` and the `D_RULE_` constants tell you which rule
  built a node.

That's the end of the tutorial. The [Reference](../reference/index.md)
covers everything in full detail.
