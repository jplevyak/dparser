/*
  Copyright 2002-2008 John Plevyak, All Rights Reserved
*/

#include "d.h"

/* tunables */
#define DEFAULT_COMMIT_ACTIONS_INTERVAL 100
#define PNODE_HASH_INITIAL_SIZE_INDEX 10
#define SNODE_HASH_INITIAL_SIZE_INDEX 8
#define ERROR_RECOVERY_QUEUE_SIZE 10000

#define LATEST(_p, _pn)                                                      \
    do                                                                       \
    {                                                                        \
        while ((_pn)->latest != (_pn)->latest->latest)                       \
        {                                                                    \
            PNode* t = (_pn)->latest->latest;                                \
            ref_pn(t);                                                       \
            unref_pn((_p), (_pn)->latest);                                   \
            (_pn)->latest = t;                                               \
        }                                                                    \
        (_pn) = (_pn)->latest;                                               \
    } while (0)

#ifndef USE_GC
static void free_SNode(struct Parser* p, struct SNode* s);
#define ref_pn(_pn)                                                          \
    do                                                                       \
    {                                                                        \
        (_pn)->refcount++;                                                   \
    } while (0)
#define ref_sn(_sn)                                                          \
    do                                                                       \
    {                                                                        \
        (_sn)->refcount++;                                                   \
    } while (0)
#define unref_pn(_p, _pn)                                                    \
    do                                                                       \
    {                                                                        \
        if (!--(_pn)->refcount)                                              \
            free_PNode(_p, _pn);                                             \
    } while (0)
#define unref_sn(_p, _sn)                                                    \
    do                                                                       \
    {                                                                        \
        if (!--(_sn)->refcount)                                              \
            free_SNode(_p, _sn);                                             \
    } while (0)
#else
#define ref_pn(_pn)
#define ref_sn(_sn)
#define unref_pn(_p, _pn)
#define unref_sn(_p, _sn)
#endif

typedef Stack(struct PNode*) StackPNode;
typedef Stack(struct SNode*) StackSNode;
typedef Stack(int) StackInt;

static int exhaustive_parse(Parser* p, int state);
static void free_PNode(Parser* p, PNode* pn);

void print_paren(Parser* pp, PNode* p)
{
    int i;
    char* c;
    LATEST(pp, p);
    if (!p->error_recovery)
    {
        if (p->children.n)
        {
            if (p->children.n > 1)
                printf("(");
            for (i = 0; i < p->children.n; i++)
                print_paren(pp, p->children.v[i]);
            if (p->children.n > 1)
                printf(")");
        }
        else if (p->parse_node.start_loc.s != p->parse_node.end_skip)
        {
            printf(" ");
            for (c = p->parse_node.start_loc.s; c < p->parse_node.end_skip;
                 c++)
                printf("%c", *c);
            printf(" ");
        }
    }
}

void xprint_paren(Parser* pp, PNode* p)
{
    int i;
    char* c;
    LATEST(pp, p);
    if (!p->error_recovery)
    {
        printf("[%p %s]", p, pp->t->symbols[p->parse_node.symbol].name);
        if (p->children.n)
        {
            printf("(");
            for (i = 0; i < p->children.n; i++)
                xprint_paren(pp, p->children.v[i]);
            printf(")");
        }
        else if (p->parse_node.start_loc.s != p->parse_node.end_skip)
        {
            printf(" ");
            for (c = p->parse_node.start_loc.s; c < p->parse_node.end_skip;
                 c++)
                printf("%c", *c);
            printf(" ");
        }
        if (p->ambiguities)
        {
            printf(" |OR| ");
            xprint_paren(pp, p->ambiguities);
        }
    }
}

void xPP(Parser* pp, PNode* p)
{
    xprint_paren(pp, p);
    printf("\n");
}
void PP(Parser* pp, PNode* p)
{
    print_paren(pp, p);
    printf("\n");
}

#define D_ParseNode_to_PNode(_apn)                                           \
    ((PNode*) (D_PN(_apn, -(intptr_t) & ((PNode*) (NULL))->parse_node)))

#define PNode_to_D_ParseNode(_apn)                                           \
    ((D_ParseNode*) &((PNode*) (_apn))->parse_node)

D_ParseNode* d_get_child(D_ParseNode* apn, int child)
{
    PNode* pn = D_ParseNode_to_PNode(apn);
    if (child < 0 || child >= pn->children.n)
        return NULL;
    return &pn->children.v[child]->parse_node;
}

int d_get_number_of_children(D_ParseNode* apn)
{
    PNode* pn = D_ParseNode_to_PNode(apn);
    return pn->children.n;
}

D_ParseNode* d_find_in_tree(D_ParseNode* apn, int symbol)
{
    PNode* pn = D_ParseNode_to_PNode(apn);
    D_ParseNode* res;
    int i;

    if (pn->parse_node.symbol == symbol)
        return apn;
    for (i = 0; i < pn->children.n; i++)
        if ((res = d_find_in_tree(&pn->children.v[i]->parse_node, symbol)))
            return res;
    return NULL;
}

char* d_ws_before(D_Parser* ap, D_ParseNode* apn)
{
    PNode* pn = D_ParseNode_to_PNode(apn);
    return pn->ws_before;
}

char* d_ws_after(D_Parser* ap, D_ParseNode* apn)
{
    PNode* pn = D_ParseNode_to_PNode(apn);
    return pn->ws_after;
}

#define SNODE_HASH(_s, _sc, _g)                                              \
    ((((uintptr_t)(_s)) << 12) + (((uintptr_t)(_sc))) + ((uintptr_t)(_g)))

SNode* find_SNode(Parser* p, uint state, D_Scope* sc, void* g)
{
    SNodeHash* ph = &p->snode_hash;
    SNode* sn;
    uint h = SNODE_HASH(state, sc, g);
    if (ph->v)
        for (sn = ph->v[h % ph->m]; sn; sn = sn->bucket_next)
            if (sn->state - p->t->state == state && sn->initial_scope == sc &&
                sn->initial_globals == g)
                return sn;
    return NULL;
}

void insert_SNode_internal(Parser* p, SNode* sn)
{
    SNodeHash* ph = &p->snode_hash;
    uint h = SNODE_HASH(
             sn->state - p->t->state, sn->initial_scope, sn->initial_globals),
         i;
    SNode* t;

    if (ph->n + 1 > ph->m)
    {
        SNode** v = ph->v;
        int m = ph->m;
        ph->i++;
        ph->m = d_prime2[ph->i];
        ph->v = (SNode**) MALLOC(ph->m * sizeof(*ph->v));
        memset(ph->v, 0, ph->m * sizeof(*ph->v));
        for (i = 0; i < m; i++)
            while ((t = v[i]))
            {
                v[i] = v[i]->bucket_next;
                insert_SNode_internal(p, t);
            }
        FREE(v);
    }
    sn->bucket_next = ph->v[h % ph->m];
    assert(sn->bucket_next != sn);
    ph->v[h % ph->m] = sn;
    ph->n++;
}

static void insert_SNode(Parser* p, SNode* sn)
{
    insert_SNode_internal(p, sn);
    ref_sn(sn);
    sn->all_next = p->snode_hash.all;
    p->snode_hash.all = sn;
}

static SNode*
new_SNode(Parser* p, D_State* state, d_loc_t* loc, D_Scope* sc, void* g)
{
    SNode* sn = p->free_snodes;
    if (!sn)
        sn = MALLOC(sizeof *sn);
    else
        p->free_snodes = sn->all_next;
    sn->depth = 0;
    vec_clear(&sn->zns);
#ifndef USE_GC
    sn->refcount = 0;
#endif
    sn->all_next = 0;
    p->states++;
    sn->state = state;
    sn->initial_scope = sc;
    sn->initial_globals = g;
    sn->last_pn = NULL;
    sn->loc = *loc;
    insert_SNode(p, sn);
    if (sn->state->accept)
    {
        if (!p->accept)
        {
            ref_sn(sn);
            p->accept = sn;
        }
        else if (sn->loc.s > p->accept->loc.s)
        {
            ref_sn(sn);
            unref_sn(p, p->accept);
            p->accept = sn;
        }
    }
    return sn;
}

static ZNode* new_ZNode(Parser* p, PNode* pn)
{
    ZNode* z = p->free_znodes;
    if (!z)
        z = MALLOC(sizeof *z);
    else
        p->free_znodes = znode_next(z);
    z->pn = pn;
    ref_pn(pn);
    vec_clear(&z->sns);
    return z;
}

static void free_PNode(Parser* p, PNode* pn)
{
    PNode* amb;
    int i;
    if (p->user.free_node_fn)
        p->user.free_node_fn(&pn->parse_node);
    for (i = 0; i < pn->children.n; i++)
        unref_pn(p, pn->children.v[i]);
    vec_free(&pn->children);
    if ((amb = pn->ambiguities))
    {
        pn->ambiguities = NULL;
        unref_pn(p, amb);
    }
    if (pn->latest != pn)
        unref_pn(p, pn->latest);
#ifdef USE_FREELISTS
    pn->all_next = p->free_pnodes;
    p->free_pnodes = pn;
#else
    FREE(pn);
#endif
#ifdef TRACK_PNODES
    if (pn->xprev)
        pn->xprev->xnext = pn->xnext;
    else
        p->xall = pn->xnext;
    if (pn->xnext)
        pn->xnext->xprev = pn->xprev;
    pn->xprev = NULL;
    pn->xnext = NULL;
#endif
}

#ifndef USE_GC
static void free_ZNode(Parser* p, ZNode* z, SNode* s)
{
    int i;
    unref_pn(p, z->pn);
    for (i = 0; i < z->sns.n; i++)
        if (s != z->sns.v[i])
            unref_sn(p, z->sns.v[i]);
    vec_free(&z->sns);
#ifdef USE_FREELISTS
    znode_next(z) = p->free_znodes;
    p->free_znodes = z;
#else
    FREE(z);
#endif
}

static void free_SNode(Parser* p, struct SNode* s)
{
    int i;
    for (i = 0; i < s->zns.n; i++)
        if (s->zns.v[i])
            free_ZNode(p, s->zns.v[i], s);
    vec_free(&s->zns);
    if (s->last_pn)
        unref_pn(p, s->last_pn);
#ifdef USE_FREELISTS
    s->all_next = p->free_snodes;
    p->free_snodes = s;
#else
    FREE(s);
#endif
}
#else
#define free_ZNode(_p, _z, _s)
#endif

#define PNODE_HASH(_si, _ei, _s, _sc, _g)                                    \
    ((((uintptr_t) _si) << 8) + (((uintptr_t) _ei) << 16) +                  \
     (((uintptr_t) _s)) + (((uintptr_t) _sc)) + (((uintptr_t) _g)))

PNode* find_PNode(Parser* p,
                  char* start,
                  char* end_skip,
                  int symbol,
                  D_Scope* sc,
                  void* g,
                  uint* hash)
{
    PNodeHash* ph = &p->pnode_hash;
    PNode* pn;
    uint h = PNODE_HASH(start, end_skip, symbol, sc, g);
    *hash = h;
    if (ph->v)
        for (pn = ph->v[h % ph->m]; pn; pn = pn->bucket_next)
            if (pn->hash == h && pn->parse_node.symbol == symbol &&
                pn->parse_node.start_loc.s == start &&
                pn->parse_node.end_skip == end_skip &&
                pn->initial_scope == sc && pn->initial_globals == g)
            {
                LATEST(p, pn);
                return pn;
            }
    return NULL;
}

void insert_PNode_internal(Parser* p, PNode* pn)
{
    PNodeHash* ph = &p->pnode_hash;
    uint h = PNODE_HASH(pn->parse_node.start_loc.s,
                        pn->parse_node.end_skip,
                        pn->parse_node.symbol,
                        pn->initial_scope,
                        pn->initial_globals),
         i;
    PNode* t;

    if (ph->n + 1 > ph->m)
    {
        PNode** v = ph->v;
        int m = ph->m;
        ph->i++;
        ph->m = d_prime2[ph->i];
        ph->v = (PNode**) MALLOC(ph->m * sizeof(*ph->v));
        memset(ph->v, 0, ph->m * sizeof(*ph->v));
        for (i = 0; i < m; i++)
            while ((t = v[i]))
            {
                v[i] = v[i]->bucket_next;
                insert_PNode_internal(p, t);
            }
        FREE(v);
    }
    pn->bucket_next = ph->v[h % ph->m];
    ph->v[h % ph->m] = pn;
    ph->n++;
}

static void insert_PNode(Parser* p, PNode* pn)
{
    insert_PNode_internal(p, pn);
    ref_pn(pn);
    pn->all_next = p->pnode_hash.all;
    p->pnode_hash.all = pn;
}

static void free_old_nodes(Parser* p)
{
    int i;
    uint h;
    PNode *pn = p->pnode_hash.all, *tpn, **lpn;
    SNode *sn = p->snode_hash.all, *tsn, **lsn;
    while (sn)
    {
        h = SNODE_HASH(
            sn->state - p->t->state, sn->initial_scope, sn->initial_globals);
        lsn = &p->snode_hash.v[h % p->snode_hash.m];
        tsn = sn;
        sn = sn->all_next;
        while (*lsn != tsn)
            lsn = &(*lsn)->bucket_next;
        *lsn = (*lsn)->bucket_next;
    }
    sn = p->snode_hash.last_all;
    p->snode_hash.last_all = 0;
    while (sn)
    {
        tsn = sn;
        sn = sn->all_next;
        unref_sn(p, tsn);
    }
    p->snode_hash.last_all = p->snode_hash.all;
    p->snode_hash.all = NULL;
    while (pn)
    {
        for (i = 0; i < pn->children.n; i++)
        {
            while (pn->children.v[i] != pn->children.v[i]->latest)
            {
                tpn = pn->children.v[i]->latest;
                ref_pn(tpn);
                unref_pn(p, pn->children.v[i]);
                pn->children.v[i] = tpn;
            }
        }
        h = PNODE_HASH(pn->parse_node.start_loc.s,
                       pn->parse_node.end_skip,
                       pn->parse_node.symbol,
                       pn->initial_scope,
                       pn->initial_globals);
        lpn = &p->pnode_hash.v[h % p->pnode_hash.m];
        tpn = pn;
        pn = pn->all_next;
        while (*lpn != tpn)
            lpn = &(*lpn)->bucket_next;
        *lpn = (*lpn)->bucket_next;
        unref_pn(p, tpn);
    }
    p->pnode_hash.n = 0;
    p->pnode_hash.all = NULL;
}

static void alloc_parser_working_data(Parser* p)
{
    p->pnode_hash.i = PNODE_HASH_INITIAL_SIZE_INDEX;
    p->pnode_hash.m = d_prime2[p->pnode_hash.i];
    p->pnode_hash.v =
        (PNode**) MALLOC(p->pnode_hash.m * sizeof(*p->pnode_hash.v));
    memset(p->pnode_hash.v, 0, p->pnode_hash.m * sizeof(*p->pnode_hash.v));
    p->snode_hash.i = SNODE_HASH_INITIAL_SIZE_INDEX;
    p->snode_hash.m = d_prime2[p->snode_hash.i];
    p->snode_hash.v =
        (SNode**) MALLOC(p->snode_hash.m * sizeof(*p->snode_hash.v));
    memset(p->snode_hash.v, 0, p->snode_hash.m * sizeof(*p->snode_hash.v));
    p->nshift_results = 0;
    p->ncode_shifts = 0;
}

static void free_parser_working_data(Parser* p)
{
    int i;

    free_old_nodes(p);
    free_old_nodes(p); /* to catch SNodes saved for error repair */
    if (p->pnode_hash.v)
        FREE(p->pnode_hash.v);
    if (p->snode_hash.v)
        FREE(p->snode_hash.v);
    memset(&p->pnode_hash, 0, sizeof(p->pnode_hash));
    memset(&p->snode_hash, 0, sizeof(p->snode_hash));
    while (p->reductions_todo)
    {
        Reduction* r = p->free_reductions->next;
        unref_sn(p, p->reductions_todo->snode);
        FREE(p->free_reductions);
        p->free_reductions = r;
    }
    while (p->shifts_todo)
    {
        Shift* s = p->free_shifts->next;
        unref_sn(p, p->shifts_todo->snode);
        FREE(p->free_shifts);
        p->free_shifts = s;
    }
    while (p->free_reductions)
    {
        Reduction* r = p->free_reductions->next;
        FREE(p->free_reductions);
        p->free_reductions = r;
    }
    while (p->free_shifts)
    {
        Shift* s = p->free_shifts->next;
        FREE(p->free_shifts);
        p->free_shifts = s;
    }
    while (p->free_pnodes)
    {
        PNode* pn = p->free_pnodes->all_next;
        FREE(p->free_pnodes);
        p->free_pnodes = pn;
    }
    while (p->free_znodes)
    {
        ZNode* zn = znode_next(p->free_znodes);
        FREE(p->free_znodes);
        p->free_znodes = zn;
    }
    while (p->free_snodes)
    {
        SNode* sn = p->free_snodes->all_next;
        FREE(p->free_snodes);
        p->free_snodes = sn;
    }
    for (i = 0; i < p->error_reductions.n; i++)
        FREE(p->error_reductions.v[i]);
    vec_free(&p->error_reductions);
    if (p->whitespace_parser)
        free_parser_working_data(p->whitespace_parser);
    FREE(p->shift_results);
    p->shift_results = NULL;
    p->nshift_results = 0;
    FREE(p->code_shifts);
    p->code_shifts = NULL;
    p->ncode_shifts = 0;
}

static int znode_depth(ZNode* z)
{
    int i, d = 0;
    if (!z)
        return INT_MAX;
    for (i = 0; i < z->sns.n; i++)
        d = d < z->sns.v[i]->depth ? z->sns.v[i]->depth : d;
    return d;
}

static Reduction*
add_Reduction(Parser* p, ZNode* z, SNode* sn, D_Reduction* reduction)
{
    Reduction *x, **l = &p->reductions_todo;
    int d = znode_depth(z), dd;
    for (x = p->reductions_todo; x; l = &x->next, x = x->next)
    {
        if (sn->loc.s < x->snode->loc.s)
            break;
        dd = znode_depth(x->znode);
        if ((sn->loc.s == x->snode->loc.s && d >= dd))
        {
            if (d == dd)
                while (x)
                {
                    if (sn == x->snode && z == x->znode &&
                        reduction == x->reduction)
                        return NULL;
                    x = x->next;
                }
            break;
        }
    }
    {
        Reduction* r = p->free_reductions;
        if (!r)
            r = MALLOC(sizeof *r);
        else
            p->free_reductions = r->next;
        r->znode = z;
        r->snode = sn;
        r->new_snode = NULL;
        ref_sn(sn);
        r->reduction = reduction;
        r->next = *l;
        *l = r;
        return r;
    }
}

static void add_Shift(Parser* p, SNode* snode)
{
    Shift *x, **l = &p->shifts_todo;
    Shift* s = p->free_shifts;
    if (!s)
        s = MALLOC(sizeof *s);
    else
        p->free_shifts = s->next;
    s->snode = snode;
    ref_sn(s->snode);
    for (x = p->shifts_todo; x; l = &x->next, x = x->next)
        if (snode->loc.s <= x->snode->loc.s)
            break;
    s->next = *l;
    *l = s;
}

static SNode*
add_SNode(Parser* p, D_State* state, d_loc_t* loc, D_Scope* sc, void* g)
{
    int i;
    SNode* sn = find_SNode(p, state - p->t->state, sc, g);
    if (sn)
        return sn;
    sn = new_SNode(p, state, loc, sc, g);
    if (sn->state->shifts)
        add_Shift(p, sn);
    for (i = 0; i < sn->state->reductions.n; i++)
        if (!sn->state->reductions.v[i]->nelements)
            add_Reduction(p, 0, sn, sn->state->reductions.v[i]);
    return sn;
}

static int reduce_actions(Parser* p, PNode* pn, D_Reduction* r)
{
    int i, height = 0;
    PNode* c;

    for (i = 0; i < pn->children.n; i++)
    {
        c = pn->children.v[i];
        if (c->op_assoc)
        {
            pn->assoc = c->op_assoc;
            pn->priority = c->op_priority;
        }
        if (c->height >= height)
            height = c->height + 1;
    }
    pn->op_assoc = r->op_assoc;
    pn->op_priority = r->op_priority;
    pn->height = height;
    if (r->rule_assoc)
    {
        pn->assoc = r->rule_assoc;
        pn->priority = r->rule_priority;
    }
    if (r->speculative_code)
        return r->speculative_code(pn,
                                   (void**) &pn->children.v[0],
                                   pn->children.n,
                                   (intptr_t) & ((PNode*) (NULL))->parse_node,
                                   (D_Parser*) p);
    return 0;
}

#define x 666 /* impossible */
static int child_table[4][3][6] = {
    {
        /* binary parent, child on left */
        /* priority of child vs parent, or = with child|parent associativity
           > < =LL =LR =RL =RR
         */
        {1, 0, 1, 1, 0, 0}, /* binary child */
        {1, 1, 1, 1, x, x}, /* left unary child */
        {1, 0, x, x, 1, 1}  /* right unary child */
    },
    {
        /* binary parent, child on right */
        {1, 0, 0, 0, 1, 1}, /* binary child */
        {1, 0, 1, 1, x, x}, /* left unary child */
        {1, 1, x, x, 1, 1}  /* right unary child */
    },
    {
        /* left unary parent */
        {1, 0, 0, x, 0, x}, /* binary child */
        {1, 1, 1, x, x, x}, /* left unary child */
        {1, 0, x, x, 1, x}  /* right unary child */
    },
    {
        /* right unary parent */
        {1, 0, x, 0, x, 0}, /* binary child */
        {1, 0, x, 1, x, x}, /* left unary child */
        {1, 1, x, x, x, 1}  /* right unary child */
    }};
#undef x

/* returns 1 if legal for child reduction and illegal for child shift */
static int check_child(int ppri,
                       AssocKind passoc,
                       int cpri,
                       AssocKind cassoc,
                       int left,
                       int right)
{
    int p = IS_BINARY_NARY_ASSOC(passoc)
                ? (right ? 1 : 0)
                : (passoc == ASSOC_UNARY_LEFT ? 2 : 3);
    int c = IS_BINARY_NARY_ASSOC(cassoc)
                ? 0
                : (cassoc == ASSOC_UNARY_LEFT ? 1 : 2);
    int r =
        cpri > ppri
            ? 0
            : (cpri < ppri ? 1 : (2 + ((IS_RIGHT_ASSOC(cassoc) ? 2 : 0) +
                                       (IS_RIGHT_ASSOC(passoc) ? 1 : 0))));
    return child_table[p][c][r];
}

/* check assoc/priority legality, 0 is OK, -1 is bad */
static int check_assoc_priority(PNode* pn0, PNode* pn1, PNode* pn2)
{
    if (!IS_UNARY_BINARY_ASSOC(pn0->op_assoc))
    {
        if (IS_UNARY_BINARY_ASSOC(pn1->op_assoc))
        { /* second token is operator */
            /* check expression pn0 (child of pn1) */
            if (pn0->assoc)
            {
                if (!check_child(pn1->op_priority,
                                 pn1->op_assoc,
                                 pn0->priority,
                                 pn0->assoc,
                                 0,
                                 1))
                    return -1;
            }
        }
    }
    else
    { /* pn0 is an operator */
        if (pn1->op_assoc)
        {
            /* check pn0 (child of operator pn1) */
            if (!check_child(pn1->op_priority,
                             pn1->op_assoc,
                             pn0->op_priority,
                             pn0->op_assoc,
                             0,
                             1))
                return -1;
        }
        else if (pn2)
        {
            /* check pn0 (child of operator pn2) */
            if (pn2->op_assoc &&
                !check_child(pn2->op_priority,
                             pn2->op_assoc,
                             pn0->op_priority,
                             pn0->op_assoc,
                             0,
                             1))
                return -1;
        }
        /* check expression pn1 (child of pn0)  */
        if (pn1->assoc)
        {
            if (!check_child(pn0->op_priority,
                             pn0->op_assoc,
                             pn1->priority,
                             pn1->assoc,
                             1,
                             0))
                return -1;
        }
    }
    return 0;
}

/* check to see if a path is legal with respect to
   the associativity and priority of its operators */
static int check_path_priorities_internal(VecZNode* path)
{
    int i = 0, j, k, jj, kk, one = 0;
    ZNode *z, *zz, *zzz;
    PNode *pn0, *pn1;

    if (path->n < i + 1)
        return 0;
    pn0 = path->v[i]->pn;
    if (!pn0->op_assoc)
    { /* deal with top expression directly */
        i = 1;
        if (path->n < i + 1)
            return 0;
        pn1 = path->v[i]->pn;
        if (!pn1->op_assoc)
            return 0;
        if (pn0->assoc)
        {
            if (!check_child(pn1->op_priority,
                             pn1->op_assoc,
                             pn0->priority,
                             pn0->assoc,
                             0,
                             1))
                return -1;
        }
        pn0 = pn1;
    }
    if (path->n > i + 1)
    { /* entirely in the path */
        pn1 = path->v[i + 1]->pn;
        if (path->n > i + 2)
            return check_assoc_priority(pn0, pn1, path->v[i + 2]->pn);
        else
        { /* one level from the stack beyond the path */
            z = path->v[i + 1];
            for (k = 0; k < z->sns.n; k++)
                for (j = 0; j < z->sns.v[k]->zns.n; j++)
                {
                    one = 1;
                    zz = z->sns.v[k]->zns.v[j];
                    if (zz && !check_assoc_priority(pn0, pn1, zz->pn))
                        return 0;
                }
            if (!one)
                return check_assoc_priority(pn0, pn1, NULL);
        }
    }
    else
    { /* two levels from the stack beyond the path */
        z = path->v[i];
        for (k = 0; k < z->sns.n; k++)
            for (j = 0; j < z->sns.v[k]->zns.n; j++)
            {
                zz = z->sns.v[k]->zns.v[j];
                if (zz)
                    for (kk = 0; kk < zz->sns.n; kk++)
                        for (jj = 0; jj < zz->sns.v[kk]->zns.n; jj++)
                        {
                            one = 1;
                            zzz = zz->sns.v[kk]->zns.v[jj];
                            if (zzz &&
                                !check_assoc_priority(pn0, zz->pn, zzz->pn))
                                return 0;
                        }
            }
        return 0;
    }
    return -1;
}

/* avoid cases without operator priorities */
#define check_path_priorities(_p)                                            \
    ((_p)->n > 1 &&                                                          \
     ((_p)->v[0]->pn->op_assoc || (_p)->v[1]->pn->op_assoc) &&               \
     check_path_priorities_internal(_p))

static int compare_priorities(int xpri[], int xn, int ypri[], int yn)
{
    int i = 0;

    while (i < xn && i < yn)
    {
        if (xpri[i] > ypri[i])
            return -1;
        if (xpri[i] < ypri[i])
            return 1;
        i++;
    }
    return 0;
}

static void intreverse(int* xp, int n)
{
    int *a = xp, *b = xp + n - 1;
    while (a < b)
    {
        int t = *a;
        *a = *b;
        *b = t;
        a++;
        b--;
    }
}

/* sort by deepest, then by location */
static void priority_insert(StackPNode* psx, PNode* x)
{
    PNode *t, **start, **cur;

    stack_push(psx, x);
    start = psx->start;
    cur = psx->cur;
    for (; cur > start + 1; cur--)
    {
        if (cur[-1]->height > cur[-2]->height)
            continue;
        if (cur[-1]->height == cur[-2]->height &&
            cur[-1]->parse_node.start_loc.s > cur[-2]->parse_node.start_loc.s)
            continue;
        t = cur[-1];
        cur[-1] = cur[-2];
        cur[-2] = t;
    }
}

static void get_exp_all(Parser* p, PNode* x, StackInt* psx)
{
    int i;

    if (x->assoc)
        stack_push(psx, x->priority);
    for (i = 0; i < x->children.n; i++)
    {
        PNode* pn = x->children.v[i];
        LATEST(p, pn);
        get_exp_all(p, pn, psx);
    }
}

static void get_exp_one(Parser* p, PNode* x, StackPNode* psx, StackInt* isx)
{
    int i;

    LATEST(p, x);
    if (!IS_NARY_ASSOC(x->assoc))
        priority_insert(psx, x);
    else
    {
        stack_push(isx, x->priority);
        for (i = 0; i < x->children.n; i++)
            if (x->children.v[i]->assoc)
                get_exp_one(p, x->children.v[i], psx, isx);
    }
}

static void
get_exp_one_down(Parser* p, PNode* x, StackPNode* psx, StackInt* isx)
{
    int i;

    LATEST(p, x);
    stack_push(isx, x->priority);
    for (i = 0; i < x->children.n; i++)
        if (x->children.v[i]->assoc)
            get_exp_one(p, x->children.v[i], psx, isx);
}

/* get the set of priorities for unshared nodes,
   eliminating shared subtrees via priority queues */
static void get_unshared_priorities(
    Parser* p, StackPNode* psx, StackPNode* psy, StackInt* isx, StackInt* isy)
{
    StackPNode* psr;
    PNode* t;

    while (1)
    {
        if (is_stack_empty(psx))
        {
            psr = psy;
            break;
        }
        else if (is_stack_empty(psy))
        {
            psr = psx;
            break;
        }
        if (stack_head(psx)->height > stack_head(psy)->height)
            psr = psx;
        else if (stack_head(psx)->height < stack_head(psy)->height)
            psr = psy;
        else if (stack_head(psx) > stack_head(psy))
            psr = psx;
        else if (stack_head(psx) < stack_head(psy))
            psr = psy;
        else
        {
            (void) stack_pop(psx);
            (void) stack_pop(psy);
            continue;
        }
        t = stack_pop(psr);
        if (psr == psx)
            get_exp_one_down(p, t, psx, isx);
        else
            get_exp_one_down(p, t, psy, isy);
    }
    while (!is_stack_empty(psr))
    {
        t = stack_pop(psr);
        if (psr == psx)
            get_exp_all(p, t, isx);
        else
            get_exp_all(p, t, isy);
    }
    return;
}

/* compare the priorities of operators in two trees
   while eliminating common subtrees for efficiency.
*/
static int cmp_priorities(Parser* p, PNode* x, PNode* y)
{
    StackPNode psx, psy;
    StackInt isx, isy;

    stack_clear(&psx);
    stack_clear(&psy);
    stack_clear(&isx);
    stack_clear(&isy);
    get_exp_one(p, x, &psx, &isx);
    get_exp_one(p, y, &psy, &isy);
    get_unshared_priorities(p, &psx, &psy, &isx, &isy);
    intreverse(isx.start, stack_depth(&isx));
    intreverse(isy.start, stack_depth(&isy));
    int r = compare_priorities(
        isx.start, stack_depth(&isx), isy.start, stack_depth(&isy));
    stack_free(&psx);
    stack_free(&psy);
    stack_free(&isx);
    stack_free(&isy);
    return r;
}

static void get_all(Parser* p, PNode* x, VecPNode* vx)
{
    int i;
    if (set_add(vx, x))
    {
        for (i = 0; i < x->children.n; i++)
        {
            PNode* pn = x->children.v[i];
            LATEST(p, pn);
            get_all(p, pn, vx);
        }
    }
}

static void get_unshared_pnodes(
    Parser* p, PNode* x, PNode* y, VecPNode* pvx, VecPNode* pvy)
{
    int i;
    VecPNode vx, vy;
    vec_clear(&vx);
    vec_clear(&vy);
    LATEST(p, x);
    LATEST(p, y);
    get_all(p, x, &vx);
    get_all(p, y, &vy);
    for (i = 0; i < vx.n; i++)
        if (vx.v[i] && !set_find(&vy, vx.v[i]))
            vec_add(pvx, vx.v[i]);
    for (i = 0; i < vy.n; i++)
        if (vy.v[i] && !set_find(&vx, vy.v[i]))
            vec_add(pvy, vy.v[i]);
    vec_free(&vx);
    vec_free(&vy);
}

static int greedycmp(const void* ax, const void* ay)
{
    PNode* x = *(PNode**) ax;
    PNode* y = *(PNode**) ay;
    // first by start
    if (x->parse_node.start_loc.s < y->parse_node.start_loc.s)
        return -1;
    if (x->parse_node.start_loc.s > y->parse_node.start_loc.s)
        return 1;
    // second by symbol
    if (x->parse_node.symbol < y->parse_node.symbol)
        return -1;
    if (x->parse_node.symbol > y->parse_node.symbol)
        return 1;
    // third by length
    if (x->parse_node.end < y->parse_node.end)
        return -1;
    if (x->parse_node.end > y->parse_node.end)
        return 1;
    return 0;
}

#define RET(_x)                                                              \
    do                                                                       \
    {                                                                        \
        ret = (_x);                                                          \
        goto Lreturn;                                                        \
    } while (0)

static int cmp_greediness(Parser* p, PNode* x, PNode* y)
{
    VecPNode pvx, pvy;
    vec_clear(&pvx);
    vec_clear(&pvy);
    get_unshared_pnodes(p, x, y, &pvx, &pvy);
    /* set_to_vec(&pvx); set_to_vec(&pvy); */
    qsort(pvx.v, pvx.n, sizeof(PNode*), greedycmp);
    qsort(pvy.v, pvy.n, sizeof(PNode*), greedycmp);
    int ix = 0, iy = 0, ret = 0;
    while (1)
    {
        if (pvx.n <= ix || pvy.n <= iy)
            RET(0);
        x = pvx.v[ix];
        y = pvy.v[iy];
        if (x == y)
        {
            ix++;
            iy++;
        }
        else if (x->parse_node.start_loc.s < y->parse_node.start_loc.s)
            ix++;
        else if (x->parse_node.start_loc.s > y->parse_node.start_loc.s)
            iy++;
        else if (x->parse_node.symbol < y->parse_node.symbol)
            ix++;
        else if (x->parse_node.symbol > y->parse_node.symbol)
            iy++;
        else if (x->parse_node.end > y->parse_node.end)
            RET(-1);
        else if (x->parse_node.end < y->parse_node.end)
            RET(1);
        else if (x->children.n < y->children.n)
            RET(-1);
        else if (x->children.n > y->children.n)
            RET(1);
        else
        {
            ix++;
            iy++;
        }
    }
Lreturn:
    vec_free(&pvx);
    vec_free(&pvy);
    return ret;
}

int resolve_amb_greedy(D_Parser* dp, int n, D_ParseNode** v)
{
    int i, result, selected_node = 0;

    for (i = 1; i < n; i++)
    {
        result = cmp_greediness((Parser*) dp,
                                D_ParseNode_to_PNode(v[i]),
                                D_ParseNode_to_PNode(v[selected_node]));
        if (result < 0 ||
            (result == 0 &&
             D_ParseNode_to_PNode(v[i])->height <
                 D_ParseNode_to_PNode(v[selected_node])->height))
            selected_node = i;
    }
    return selected_node;
}

/* return -1 for x, 1 for y and 0 if they are ambiguous */
static int cmp_pnodes(Parser* p, PNode* x, PNode* y)
{
    int r = 0;
    if (x->assoc && y->assoc)
    {
        if ((r = cmp_priorities(p, x, y)))
            return r;
    }
    if (!p->user.dont_use_greediness_for_disambiguation)
        if ((r = cmp_greediness(p, x, y)))
            return r;
    if (!p->user.dont_use_height_for_disambiguation)
    {
        if (x->height < y->height)
            return -1;
        if (x->height > y->height)
            return 1;
    }
    return r;
}

static PNode* make_PNode(Parser* p,
                         uint hash,
                         int symbol,
                         d_loc_t* start_loc,
                         char* e,
                         PNode* pn,
                         D_Reduction* r,
                         VecZNode* path,
                         D_Shift* sh,
                         D_Scope* scope)
{
    int i,
        l = sizeof(PNode) - sizeof(d_voidp) + p->user.sizeof_user_parse_node;
    PNode* new_pn = p->free_pnodes;
    if (!new_pn)
        new_pn = MALLOC(l);
    else
        p->free_pnodes = new_pn->all_next;
    p->pnodes++;
    memset(new_pn, 0, l);
#ifdef TRACK_PNODES
    new_pn->xnext = p->xall;
    if (p->xall)
        p->xall->xprev = new_pn;
    p->xall = new_pn;
#endif
    new_pn->hash = hash;
    new_pn->parse_node.symbol = symbol;
    new_pn->parse_node.start_loc = *start_loc;
    new_pn->ws_before = start_loc->ws;
    if (!r ||
        !path) /* end of last parse node of path for non-epsilon reductions */
        new_pn->parse_node.end = e;
    else
        new_pn->parse_node.end = pn->parse_node.end;
    new_pn->parse_node.end_skip = e;
    new_pn->shift = sh;
    new_pn->reduction = r;
    new_pn->parse_node.scope = pn->parse_node.scope;
    new_pn->initial_scope = scope;
    new_pn->parse_node.globals = pn->parse_node.globals;
    new_pn->initial_globals = new_pn->parse_node.globals;
    new_pn->parse_node.white_space = pn->parse_node.white_space;
    new_pn->latest = new_pn;
    new_pn->ws_after = e;
    if (sh)
    {
        new_pn->op_assoc = sh->op_assoc;
        new_pn->op_priority = sh->op_priority;
        if (sh->speculative_code && sh->action_index != -1)
        {
            D_Reduction dummy;
            memset(&dummy, 0, sizeof(dummy));
            dummy.action_index = sh->action_index;
            new_pn->reduction = &dummy;
            if (sh->speculative_code(new_pn,
                                     (void**) &new_pn->children.v[0],
                                     new_pn->children.n,
                                     (intptr_t) &
                                         ((PNode*) (NULL))->parse_node,
                                     (D_Parser*) p))
            {
                free_PNode(p, new_pn);
                return NULL;
            }
            new_pn->reduction = NULL;
        }
    }
    else if (r)
    {
        if (path)
            for (i = path->n - 1; i >= 0; i--)
            {
                PNode* latest = path->v[i]->pn;
                LATEST(p, latest);
                ref_pn(latest);
                vec_add(&new_pn->children, latest);
            }
        if (reduce_actions(p, new_pn, r))
        {
            free_PNode(p, new_pn);
            return NULL;
        }
        if (path && path->n > 1)
        {
            int n = path->n;
            for (i = 0; i < n; i += n - 1)
            {
                PNode* child = new_pn->children.v[i];
                if (child->assoc && new_pn->assoc &&
                    !check_child(new_pn->priority,
                                 new_pn->assoc,
                                 child->priority,
                                 child->assoc,
                                 i == 0,
                                 i == n - 1))
                {
                    free_PNode(p, new_pn);
                    return NULL;
                }
            }
        }
    }
    return new_pn;
}

static int
PNode_equal(Parser* p, PNode* pn, D_Reduction* r, VecZNode* path, D_Shift* sh)
{
    int i, n = pn->children.n;
    if (sh)
        return sh == pn->shift;
    if (r != pn->reduction)
        return 0;
    if (!path && !n)
        return 1;
    if (n == path->n)
    {
        for (i = 0; i < n; i++)
        {
            PNode *x = pn->children.v[i], *y = path->v[n - i - 1]->pn;
            LATEST(p, x);
            LATEST(p, y);
            if (x != y)
                return 0;
        }
        return 1;
    }
    return 0;
}

/* find/create PNode */
static PNode* add_PNode(Parser* p,
                        int symbol,
                        d_loc_t* start_loc,
                        char* e,
                        PNode* pn,
                        D_Reduction* r,
                        VecZNode* path,
                        D_Shift* sh)
{
    D_Scope* scope = equiv_D_Scope(pn->parse_node.scope);
    uint hash;
    PNode *old_pn = find_PNode(p,
                               start_loc->s,
                               e,
                               symbol,
                               scope,
                               pn->parse_node.globals,
                               &hash),
          *new_pn;
    if (old_pn)
    {
        PNode* amb = 0;
        if (PNode_equal(p, old_pn, r, path, sh))
            return old_pn;
        for (amb = old_pn->ambiguities; amb; amb = amb->ambiguities)
        {
            if (PNode_equal(p, amb, r, path, sh))
                return old_pn;
        }
    }
    new_pn =
        make_PNode(p, hash, symbol, start_loc, e, pn, r, path, sh, scope);
    if (!old_pn)
    {
        old_pn = new_pn;
        if (!new_pn)
            return NULL;
        insert_PNode(p, new_pn);
        goto Lreturn;
    }
    if (!new_pn)
        goto Lreturn;
    p->compares++;
    switch (cmp_pnodes(p, new_pn, old_pn))
    {
        case 0:
            ref_pn(new_pn);
            new_pn->ambiguities = old_pn->ambiguities;
            old_pn->ambiguities = new_pn;
            break;
        case -1:
            insert_PNode(p, new_pn);
            LATEST(p, old_pn);
            ref_pn(new_pn);
            old_pn->latest = new_pn;
            old_pn = new_pn;
            break;
        case 1:
            free_PNode(p, new_pn);
            break;
    }
Lreturn:
    return old_pn;
}

/* The set of znodes associated with a state can be very large
   because of cascade reductions (for example, large expression trees).
   Use an adaptive data structure starting with a short list and
   then falling back to a direct map hash table.
*/

static void set_add_znode(VecZNode* v, ZNode* z);

static void set_union_znode(VecZNode* v, VecZNode* vv)
{
    int i;
    for (i = 0; i < vv->n; i++)
        if (vv->v[i])
            set_add_znode(v, vv->v[i]);
}

static ZNode* set_find_znode(VecZNode* v, PNode* pn)
{
    uint i, j, n = v->n, h;
    if (n <= INTEGRAL_VEC_SIZE)
    {
        for (i = 0; i < n; i++)
            if (v->v[i]->pn == pn)
                return v->v[i];
        return NULL;
    }
    h = ((uintptr_t) pn) % n;
    for (i = h, j = 0; i < v->n && j < SET_MAX_SEQUENTIAL;
         i = ((i + 1) % n), j++)
    {
        if (!v->v[i])
            return NULL;
        else if (v->v[i]->pn == pn)
            return v->v[i];
    }
    return NULL;
}

static void set_add_znode_hash(VecZNode* v, ZNode* z)
{
    VecZNode vv;
    vec_clear(&vv);
    int i, j, n = v->n;
    if (n)
    {
        uint h = ((uintptr_t) z->pn) % n;
        for (i = h, j = 0; i < v->n && j < SET_MAX_SEQUENTIAL;
             i = ((i + 1) % n), j++)
        {
            if (!v->v[i])
            {
                v->v[i] = z;
                return;
            }
        }
    }
    if (!n)
    {
        vv.v = NULL;
        v->i = INITIAL_SET_SIZE_INDEX;
    }
    else
    {
        vv.v = (void*) v->v;
        vv.n = v->n;
        v->i = v->i + 2;
    }
    v->n = d_prime2[v->i];
    v->v = MALLOC(v->n * sizeof(void*));
    memset(v->v, 0, v->n * sizeof(void*));
    if (vv.v)
    {
        set_union_znode(v, &vv);
        FREE(vv.v);
    }
    set_add_znode(v, z);
}

static void set_add_znode(VecZNode* v, ZNode* z)
{
    VecZNode vv;
    vec_clear(&vv);
    int i, n = v->n;
    if (n < INTEGRAL_VEC_SIZE)
    {
        vec_add(v, z);
        return;
    }
    if (n == INTEGRAL_VEC_SIZE)
    {
        vv = *v;
        vec_clear(v);
        for (i = 0; i < n; i++)
            set_add_znode_hash(v, vv.v[i]);
    }
    set_add_znode_hash(v, z);
}

#define GOTO_STATE(_p, _pn, _ps)                                             \
    ((_p)->t->goto_table[(_pn)->parse_node.symbol -                          \
                         (_ps)->state->goto_table_offset] -                  \
     1)
static SNode* goto_PNode(Parser* p, d_loc_t* loc, PNode* pn, SNode* ps)
{
    SNode *new_ps, *pre_ps;
    ZNode* z = NULL;
    D_State* state;
    int i, j, k, state_index;

    if (!IS_BIT_SET(ps->state->goto_valid, pn->parse_node.symbol))
        return NULL;
    state_index = GOTO_STATE(p, pn, ps);
    state = &p->t->state[state_index];
    new_ps = add_SNode(
        p, state, loc, pn->parse_node.scope, pn->parse_node.globals);
    if (new_ps->last_pn)
        unref_pn(p, new_ps->last_pn);
    ref_pn(pn);
    new_ps->last_pn = pn;

    DBG(printf("goto %d (%s) -> %d %p\n",
               (int) (ps->state - p->t->state),
               p->t->symbols[pn->parse_node.symbol].name,
               state_index,
               new_ps));
    if (ps != new_ps && new_ps->depth < ps->depth + 1)
        new_ps->depth = ps->depth + 1;
    /* find/create ZNode */
    z = set_find_znode(&new_ps->zns, pn);
    if (!z)
    { /* not found */
        set_add_znode(&new_ps->zns, (z = new_ZNode(p, pn)));
        for (j = 0; j < new_ps->state->reductions.n; j++)
            if (new_ps->state->reductions.v[j]->nelements)
                add_Reduction(p, z, new_ps, new_ps->state->reductions.v[j]);
        if (!pn->shift)
            for (j = 0; j < new_ps->state->right_epsilon_hints.n; j++)
            {
                D_RightEpsilonHint* h =
                    &new_ps->state->right_epsilon_hints.v[j];
                pre_ps = find_SNode(p,
                                    h->preceeding_state,
                                    new_ps->initial_scope,
                                    new_ps->initial_globals);
                if (!pre_ps)
                    continue;
                for (k = 0; k < pre_ps->zns.n; k++)
                    if (pre_ps->zns.v[k])
                    {
                        Reduction* r = add_Reduction(
                            p, pre_ps->zns.v[k], pre_ps, h->reduction);
                        if (r)
                        {
                            r->new_snode = new_ps;
                            r->new_depth = h->depth;
                        }
                    }
            }
    }
    for (i = 0; i < z->sns.n; i++)
        if (z->sns.v[i] == ps)
            break;
    if (i >= z->sns.n)
    { /* not found */
        vec_add(&z->sns, ps);
        if (new_ps != ps)
            ref_sn(ps);
    }
    return new_ps;
}

void parse_whitespace(D_Parser* ap, d_loc_t* loc, void** p_globals)
{
    Parser* pp = ((Parser*) ap)->whitespace_parser;
    pp->start = loc->s;
    if (!exhaustive_parse(pp, ((Parser*) ap)->t->whitespace_state))
    {
        if (pp->accept)
        {
            int old_col = loc->col, old_line = loc->line;
            *loc = pp->accept->loc;
            if (loc->line == 1)
                loc->col = old_col + loc->col;
            loc->line = old_line + (pp->accept->loc.line - 1);
            unref_sn(pp, pp->accept);
            pp->accept = NULL;
        }
    }
}

static void shift_all(Parser* p, char* pos)
{
    int i, j, nshifts = 0, ncode = 0;
    d_loc_t loc, skip_loc;
    D_WhiteSpaceFn skip_fn = NULL;
    PNode* new_pn;
    D_State* state;
    ShiftResult* r;
    Shift *saved_s = p->shifts_todo, *s = saved_s, *ss;

    loc = s->snode->loc;
    skip_loc.s = NULL;

    for (; (s = p->shifts_todo) && s->snode->loc.s == pos;)
    {
        if (p->nshift_results - nshifts < p->t->nsymbols * 2)
        {
            p->nshift_results = nshifts + p->t->nsymbols * 3;
            p->shift_results = REALLOC(
                p->shift_results, p->nshift_results * sizeof(ShiftResult));
        }
        p->shifts_todo = p->shifts_todo->next;
        p->scans++;
        state = s->snode->state;
        if (state->scanner_code)
        {
            if (p->ncode_shifts < ncode + 1)
            {
                p->ncode_shifts = ncode + 2;
                p->code_shifts = REALLOC(p->code_shifts,
                                         p->ncode_shifts * sizeof(D_Shift));
            }
            p->code_shifts[ncode].shift_kind = D_SCAN_ALL;
            p->code_shifts[ncode].term_priority = 0;
            p->code_shifts[ncode].op_assoc = 0;
            p->code_shifts[ncode].action_index = 0;
            p->code_shifts[ncode].speculative_code = 0;
            p->shift_results[nshifts].loc = loc;
            if ((state->scanner_code(&p->shift_results[nshifts].loc,
                                     &p->code_shifts[ncode].symbol,
                                     &p->code_shifts[ncode].term_priority,
                                     &p->code_shifts[ncode].op_assoc,
                                     &p->code_shifts[ncode].op_priority)))
            {
                p->shift_results[nshifts].snode = s->snode;
                p->shift_results[nshifts++].shift = &p->code_shifts[ncode++];
            }
        }
        if (state->scanner_table)
        {
            int n = scan_buffer(&loc, state, &p->shift_results[nshifts]);
            for (i = 0; i < n; i++)
                p->shift_results[nshifts + i].snode = s->snode;
            nshifts += n;
        }
    }
    for (i = 0; i < nshifts; i++)
    {
        r = &p->shift_results[i];
        if (!r->shift)
            continue;
        if (r->shift->shift_kind == D_SCAN_TRAILING)
        {
            int symbol = r->shift->symbol;
            SNode* sn = r->snode;
            r->shift = 0;
            for (j = i + 1; j < nshifts; j++)
            {
                if (p->shift_results[j].shift &&
                    sn == p->shift_results[j].snode &&
                    symbol == p->shift_results[j].shift->symbol)
                {
                    r->shift = p->shift_results[j].shift;
                    p->shift_results[j].shift = 0;
                }
            }
        }
        if (r->shift && r->shift->term_priority)
        {
            /* potentially n^2 but typically small */
            for (j = 0; j < nshifts; j++)
            {
                if (!p->shift_results[j].shift)
                    continue;
                if (r->loc.s == p->shift_results[j].loc.s && j != i)
                {
                    if (r->shift->term_priority <
                        p->shift_results[j].shift->term_priority)
                    {
                        r->shift = 0;
                        break;
                    }
                    if (r->shift->term_priority >
                        p->shift_results[j].shift->term_priority)
                        p->shift_results[j].shift = 0;
                }
            }
        }
    }
    for (i = 0; i < nshifts; i++)
    {
        r = &p->shift_results[i];
        if (!r->shift)
            continue;
        p->shifts++;
        DBG(printf("shift %d %p %d (%s)\n",
                   (int) (r->snode->state - p->t->state),
                   r->snode,
                   r->shift->symbol,
                   p->t->symbols[r->shift->symbol].name));
        new_pn = add_PNode(p,
                           r->shift->symbol,
                           &r->snode->loc,
                           r->loc.s,
                           r->snode->last_pn,
                           NULL,
                           NULL,
                           r->shift);
        if (new_pn)
        {
            if (!skip_loc.s || skip_loc.s != r->loc.s ||
                skip_fn != new_pn->parse_node.white_space)
            {
                skip_loc = r->loc;
                skip_fn = new_pn->parse_node.white_space;
                new_pn->parse_node.white_space(
                    (D_Parser*) p,
                    &skip_loc,
                    (void**) &new_pn->parse_node.globals);
                skip_loc.ws = r->loc.s;
                new_pn->ws_before = loc.ws;
                new_pn->ws_after = skip_loc.s;
            }
            goto_PNode(p, &skip_loc, new_pn, r->snode);
        }
    }
    for (s = saved_s; s && s->snode->loc.s == pos;)
    {
        ss = s;
        s = s->next;
        unref_sn(p, ss->snode);
        ss->next = p->free_shifts;
        p->free_shifts = ss;
    }
}

static VecZNode path1; /* static first path for speed */

static VecZNode* new_VecZNode(VecVecZNode* paths, int n, int parent)
{
    int i;
    VecZNode* pv;

    if (!paths->n)
        pv = &path1;
    else
        pv = MALLOC(sizeof *pv);
    vec_clear(pv);
    if (parent >= 0)
        for (i = 0; i < n; i++)
            vec_add(pv, paths->v[parent]->v[i]);
    return pv;
}

static void build_paths_internal(
    ZNode* z, VecVecZNode* paths, int parent, int n, int n_to_go)
{
    int j, k, l;

    vec_add(paths->v[parent], z);
    if (n_to_go <= 1)
        return;
    for (k = 0; k < z->sns.n; k++)
        for (j = 0, l = 0; j < z->sns.v[k]->zns.n; j++)
        {
            if (z->sns.v[k]->zns.v[j])
            {
                if (k + l)
                {
                    vec_add(paths,
                            new_VecZNode(paths, n - (n_to_go - 1), parent));
                    parent = paths->n - 1;
                }
                build_paths_internal(
                    z->sns.v[k]->zns.v[j], paths, parent, n, n_to_go - 1);
                l++;
            }
        }
}

static void build_paths(ZNode* z, VecVecZNode* paths, int nchildren_to_go)
{
    if (!nchildren_to_go)
        return;
    vec_add(paths, new_VecZNode(paths, 0, -1));
    build_paths_internal(z, paths, 0, nchildren_to_go, nchildren_to_go);
}

static void free_paths(VecVecZNode* paths)
{
    int i;
    for (i = 0; i < paths->n; i++)
    {
        vec_free(paths->v[i]);
        if (paths->v[i] != &path1)
            FREE(paths->v[i]);
    }
    vec_free(paths);
}

static void reduce_one(Parser* p, Reduction* r)
{
    SNode* sn = r->snode;
    PNode *pn, *last_pn;
    ZNode* first_z;
    int i, j, n = r->reduction->nelements;
    VecVecZNode paths;
    VecZNode* path;

    if (!r->znode)
    { /* epsilon reduction */
        if ((pn = add_PNode(p,
                            r->reduction->symbol,
                            &sn->loc,
                            sn->loc.s,
                            sn->last_pn,
                            r->reduction,
                            0,
                            0)))
            goto_PNode(p, &sn->loc, pn, sn);
    }
    else
    {
        DBG(printf("reduce %d %p %d\n",
                   (int) (r->snode->state - p->t->state),
                   sn,
                   n));
        vec_clear(&paths);
        build_paths(r->znode, &paths, n);
        for (i = 0; i < paths.n; i++)
        {
            path = paths.v[i];
            if (r->new_snode)
            { /* prune paths by new right epsilon node */
                for (j = 0; j < path->v[r->new_depth]->sns.n; j++)
                    if (path->v[r->new_depth]->sns.v[j] == r->new_snode)
                        break;
                if (j >= path->v[r->new_depth]->sns.n)
                    continue;
            }
            if (check_path_priorities(path))
                continue;
            p->reductions++;
            last_pn = path->v[0]->pn;
            first_z = path->v[n - 1];
            pn = add_PNode(p,
                           r->reduction->symbol,
                           &first_z->pn->parse_node.start_loc,
                           sn->loc.s,
                           last_pn,
                           r->reduction,
                           path,
                           NULL);
            if (pn)
                for (j = 0; j < first_z->sns.n; j++)
                    goto_PNode(p, &sn->loc, pn, first_z->sns.v[j]);
        }
        free_paths(&paths);
    }
    unref_sn(p, sn);
    r->next = p->free_reductions;
    p->free_reductions = r;
}

static int VecSNode_equal(VecSNode* vsn1, VecSNode* vsn2)
{
    int i, j;
    if (vsn1->n != vsn2->n)
        return 0;
    for (i = 0; i < vsn1->n; i++)
    {
        for (j = 0; j < vsn2->n; j++)
        {
            if (vsn1->v[i] == vsn2->v[j])
                break;
        }
        if (j >= vsn2->n)
            return 0;
    }
    return 1;
}

static ZNode* binary_op_ZNode(SNode* sn)
{
    ZNode* z;
    if (sn->zns.n != 1)
        return NULL;
    z = sn->zns.v[0];
    if (z->pn->op_assoc == ASSOC_UNARY_RIGHT)
    {
        if (z->sns.n != 1)
            return NULL;
        sn = z->sns.v[0];
        if (sn->zns.n != 1)
            return NULL;
        z = sn->zns.v[0];
    }
    if (!IS_BINARY_ASSOC(z->pn->op_assoc))
        return NULL;
    return z;
}

#ifdef D_DEBUG

static const char* spaces = "                                                "
                            "                                                "
                            "  ";
static void print_stack(Parser* p, SNode* s, int indent)
{
    int i, j;

    printf("%d", (int) (s->state - p->t->state));
    indent += 2;
    for (i = 0; i < s->zns.n; i++)
    {
        if (!s->zns.v[i])
            continue;
        if (s->zns.n > 1)
            printf("\n%s[", &spaces[99 - indent]);
        printf("(%s:",
               p->t->symbols[s->zns.v[i]->pn->parse_node.symbol].name);
        print_paren(p, s->zns.v[i]->pn);
        printf(")");
        for (j = 0; j < s->zns.v[i]->sns.n; j++)
        {
            if (s->zns.v[i]->sns.n > 1)
                printf("\n%s[", &spaces[98 - indent]);
            print_stack(p, s->zns.v[i]->sns.v[j], indent);
            if (s->zns.v[i]->sns.n > 1)
                printf("]");
        }
        if (s->zns.n > 1)
            printf("]");
    }
}
#endif

/* compare two stacks with operators on top of identical substacks
   eliminating the stack with the lower priority binary operator
   - used to eliminate unnecessary stacks created by the
     (empty) application binary operator
*/
static void cmp_stacks(Parser* p)
{
    char* pos;
    Shift *a, *b, **al, **bl;
    ZNode *az, *bz;

    pos = p->shifts_todo->snode->loc.s;
    DBG({
        int i = 0;
        for (al = &p->shifts_todo, a = *al; a && a->snode->loc.s == pos;
             al = &a->next, a = a->next)
        {
            if (++i < 2)
                printf("\n");
            print_stack(p, a->snode, 0);
            printf("\n");
        }
    });
    for (al = &p->shifts_todo, a = *al; a && a->snode->loc.s == pos;
         al = &a->next, a = a->next)
    {
        if (!(az = binary_op_ZNode(a->snode)))
            continue;
        for (bl = &a->next, b = a->next; b && b->snode->loc.s == pos;
             bl = &b->next, b = b->next)
        {
            if (!(bz = binary_op_ZNode(b->snode)))
                continue;
            if (!VecSNode_equal(&az->sns, &bz->sns))
                continue;
            if ((a->snode->state->reduces_to !=
                 b->snode->state - p->t->state) &&
                (b->snode->state->reduces_to !=
                 a->snode->state - p->t->state))
                continue;
            if (az->pn->op_priority > bz->pn->op_priority)
            {
                DBG(printf("DELETE "); print_stack(p, b->snode, 0);
                    printf("\n"));
                *bl = b->next;
                unref_sn(p, b->snode);
                FREE(b);
                b = *bl;
                break;
            }
            if (az->pn->op_priority < bz->pn->op_priority)
            {
                DBG(printf("DELETE "); print_stack(p, a->snode, 0);
                    printf("\n"));
                *al = a->next;
                unref_sn(p, a->snode);
                FREE(a);
                a = *al;
                goto Lbreak2;
            }
        }
    Lbreak2:;
    }
}

static void free_ParseTreeBelow(Parser* p, PNode* pn)
{
    int i;
    PNode* amb;

    for (i = 0; i < pn->children.n; i++)
        unref_pn(p, pn->children.v[i]);
    vec_free(&pn->children);
    if ((amb = pn->ambiguities))
    {
        pn->ambiguities = NULL;
        free_PNode(p, amb);
    }
}

void free_D_ParseTreeBelow(D_Parser* p, D_ParseNode* dpn)
{
    free_ParseTreeBelow((Parser*) p, DPN_TO_PN(dpn));
}

D_ParseNode* ambiguity_count_fn(D_Parser* pp, int n, D_ParseNode** v)
{
    Parser* p = (Parser*) pp;
    p->ambiguities += n - 1;
    return v[0];
}

D_ParseNode* ambiguity_abort_fn(D_Parser* pp, int n, D_ParseNode** v)
{
    int i;
    if (d_verbose_level)
    {
        for (i = 0; i < n; i++)
        {
            print_paren((Parser*) pp, D_ParseNode_to_PNode(v[i]));
            printf("\n");
        }
    }
    d_fail("unresolved ambiguity line %d file %s",
           v[0]->start_loc.line,
           v[0]->start_loc.pathname);
    return v[0];
}

static int final_actionless(PNode* pn)
{
    int i;
    if (pn->reduction && pn->reduction->final_code)
        return 0;
    for (i = 0; i < pn->children.n; i++)
        if (!final_actionless(pn->children.v[i]))
            return 0;
    return 1;
}

static PNode* resolve_ambiguities(Parser* p, PNode* pn)
{
    PNode* amb;
    D_ParseNode* res;
    int efa;
    Vec(D_ParseNode*) pns;

    vec_clear(&pns);
    efa = is_epsilon_PNode(pn) && final_actionless(pn);
    vec_add(&pns, &pn->parse_node);
    for (amb = pn->ambiguities; amb; amb = amb->ambiguities)
    {
        int i, found = 0;
        LATEST(p, amb);
        if (!p->user.dont_merge_epsilon_trees)
            if (efa && is_epsilon_PNode(amb) && final_actionless(amb))
                continue;
        for (i = 0; i < pns.n; i++)
            if (pns.v[i] == &amb->parse_node)
                found = 1;
        if (!found)
            vec_add(&pns, &amb->parse_node);
    }
    if (pns.n == 1)
    {
        res = pns.v[0];
        goto Ldone;
    }
    res = p->user.ambiguity_fn((D_Parser*) p, pns.n, pns.v);
Ldone:
    vec_free(&pns);
    return D_ParseNode_to_PNode(res);
}

static void fixup_internal_symbol(Parser* p, PNode* pn, int ichild)
{
    PNode* child = pn->children.v[ichild];
    int j, n, pnn;
    n = child->children.n, pnn = pn->children.n;
    if (pn == child)
        d_fail("circular parse: unable to fixup internal symbol");
    if (n == 0)
    {
        for (j = ichild; j < pnn - 1; j++)
            pn->children.v[j] = pn->children.v[j + 1];
        pn->children.n--;
    }
    else if (n == 1)
    {
        ref_pn(child->children.v[0]);
        pn->children.v[ichild] = child->children.v[0];
    }
    else
    {
        for (j = 0; j < n - 1; j++) /* expand children vector */
            vec_add(&pn->children, NULL);
        for (j = pnn - 1; j >= ichild + 1; j--) /* move to new places */
            pn->children.v[j - 1 + n] = pn->children.v[j];
        for (j = 0; j < n; j++)
        {
            ref_pn(child->children.v[j]);
            pn->children.v[ichild + j] = child->children.v[j];
        }
    }
    unref_pn(p, child);
}

#define is_symbol_internal_or_EBNF(_p, _pn)                                  \
    ((_p)->t->symbols[(_pn)->parse_node.symbol].kind == D_SYMBOL_INTERNAL || \
     (_p)->t->symbols[(_pn)->parse_node.symbol].kind == D_SYMBOL_EBNF)
#define is_symbol_internal(_p, _pn)                                          \
    ((_p)->t->symbols[(_pn)->parse_node.symbol].kind == D_SYMBOL_INTERNAL)
#define is_unreduced_epsilon_PNode(_pn)                                      \
    (is_epsilon_PNode(_pn) &&                                                \
     ((_pn)->reduction && (_pn)->reduction->final_code))

static PNode* commit_tree(Parser* p, PNode* pn)
{
    int i, fixup_ebnf = 0, fixup = 0, internal = 0;
    LATEST(p, pn);
    if (pn->evaluated)
        return pn;
    if (!is_unreduced_epsilon_PNode(pn))
        pn->evaluated = 1;
    if (pn->ambiguities)
        pn = resolve_ambiguities(p, pn);
    fixup_ebnf = p->user.fixup_EBNF_productions;
    internal = is_symbol_internal_or_EBNF(p, pn);
    fixup = !p->user.dont_fixup_internal_productions && internal;
    for (i = 0; i < pn->children.n; i++)
    {
        PNode* tpn = commit_tree(p, pn->children.v[i]);
        if (tpn != pn->children.v[i])
        {
            ref_pn(tpn);
            unref_pn(p, pn->children.v[i]);
            pn->children.v[i] = tpn;
        }
        if (fixup &&
            (fixup_ebnf ? is_symbol_internal_or_EBNF(p, pn->children.v[i])
                        : is_symbol_internal(p, pn->children.v[i])))
        {
            fixup_internal_symbol(p, pn, i);
            i -= 1;
            continue;
        }
    }
    if (pn->reduction)
        DBG(printf("commit %p (%s)\n",
                   pn,
                   p->t->symbols[pn->parse_node.symbol].name));
    if (pn->reduction && pn->reduction->final_code)
        pn->reduction->final_code(pn,
                                  (void**) &pn->children.v[0],
                                  pn->children.n,
                                  (intptr_t) & ((PNode*) (NULL))->parse_node,
                                  (D_Parser*) p);
    if (pn->evaluated)
    {
        if (!p->user.save_parse_tree && !internal)
            free_ParseTreeBelow(p, pn);
    }
    return pn;
}

static int commit_stack(Parser* p, SNode* sn)
{
    int res = 0;
    PNode* tpn;

    if (sn->zns.n != 1)
        return -1;
    if (sn->zns.v[0]->sns.n > 1)
        return -2;
    if (is_unreduced_epsilon_PNode(sn->zns.v[0]->pn)) /* wait till reduced */
        return -3;
    if (sn->zns.v[0]->sns.n)
        if ((res = commit_stack(p, sn->zns.v[0]->sns.v[0])) < 0)
            return res;
    tpn = commit_tree(p, sn->zns.v[0]->pn);
    if (tpn != sn->zns.v[0]->pn)
    {
        ref_pn(tpn);
        unref_pn(p, sn->zns.v[0]->pn);
        sn->zns.v[0]->pn = tpn;
    }
    return res;
}

static const char* find_substr(const char* str, const char* s)
{
    int len = strlen(s);
    if (len == 1)
    {
        while (*str && *str != *s)
            str++;
        if (*str == *s)
            return str + 1;
    }
    else
        while (*str)
        {
            if (!strncmp(s, str, len))
                return str + len;
            str++;
        }
    return NULL;
}

static void syntax_error_report_fn(struct D_Parser* ap)
{
    Parser* p = (Parser*) ap;
    char* fn = d_dup_pathname_str(p->user.loc.pathname);
    char* after = 0;
    ZNode* z = p->snode_hash.last_all ? p->snode_hash.last_all->zns.v[0] : 0;
    while (z && z->pn->parse_node.start_loc.s == z->pn->parse_node.end)
        z = (z->sns.v && z->sns.v[0]->zns.v) ? z->sns.v[0]->zns.v[0] : 0;
    if (z && z->pn->parse_node.start_loc.s != z->pn->parse_node.end)
        after = dup_str(z->pn->parse_node.start_loc.s, z->pn->parse_node.end);
    if (after)
        fprintf(stderr,
                "%s:%d: syntax error after '%s'\n",
                fn,
                p->user.loc.line,
                after);
    else
        fprintf(stderr, "%s:%d: syntax error\n", fn, p->user.loc.line);
    if (after)
        FREE(after);
    FREE(fn);
}

static void update_line(const char* s, const char* e, int* line)
{
    for (; s < e; s++)
        if (*s == '\n')
            (*line)++;
}

static int error_recovery(Parser* p)
{
    SNode *sn, *best_sn = NULL;
    const char *best_s = NULL, *ss, *s;
    int i, j, head = 0, tail = 0, res = 1;
    D_ErrorRecoveryHint* best_er = NULL;
    SNode** q = 0;
    PNode* best_pn = NULL;

    if (!p->snode_hash.last_all)
        return res;
    p->user.loc = p->snode_hash.last_all->loc;
    if (!p->user.error_recovery)
        return res;
    q = MALLOC(ERROR_RECOVERY_QUEUE_SIZE * sizeof(SNode*));
    if (p->user.loc.line > p->last_syntax_error_line)
    {
        p->last_syntax_error_line = p->user.loc.line;
        p->user.syntax_errors++;
        p->user.syntax_error_fn((D_Parser*) p);
    }
    for (sn = p->snode_hash.last_all; sn; sn = sn->all_next)
    {
        if (tail < ERROR_RECOVERY_QUEUE_SIZE - 1)
            q[tail++] = sn;
    }
    s = p->snode_hash.last_all->loc.s;
    while (tail > head)
    {
        sn = q[head++];
        if (sn->state->error_recovery_hints.n)
        {
            for (i = 0; i < sn->state->error_recovery_hints.n; i++)
            {
                D_ErrorRecoveryHint* er =
                    &sn->state->error_recovery_hints.v[i];
                if ((ss = find_substr(s, er->string)))
                {
                    if (!best_sn || ss < best_s ||
                        (best_sn && ss == best_s &&
                         (best_sn->depth < sn->depth ||
                          (best_sn->depth == sn->depth &&
                           best_er->depth < er->depth))))
                    {
                        best_sn = sn;
                        best_s = ss;
                        best_er = er;
                    }
                }
            }
        }
        for (i = 0; i < sn->zns.n; i++)
            if (sn->zns.v[i])
                for (j = 0; j < sn->zns.v[i]->sns.n; j++)
                {
                    if (tail < ERROR_RECOVERY_QUEUE_SIZE - 1)
                        q[tail++] = sn->zns.v[i]->sns.v[j];
                }
    }
    if (best_sn)
    {
        D_Reduction* rr = MALLOC(sizeof(*rr));
        Reduction* r = MALLOC(sizeof(*r));
        d_loc_t best_loc = p->user.loc;
        PNode* new_pn;
        SNode* new_sn;
        ZNode* z;

        memset(rr, 0, sizeof(*rr));
        vec_add(&p->error_reductions, rr);
        rr->nelements = best_er->depth + 1;
        rr->symbol = best_er->symbol;
        update_line(best_loc.s, best_s, &best_loc.line);
        best_loc.s = (char*) best_s;
        for (i = 0; i < best_sn->zns.n; i++)
            if (best_sn->zns.v[i])
            {
                best_pn = best_sn->zns.v[i]->pn;
                break;
            }
        best_pn->parse_node.white_space(
            (D_Parser*) p, &best_loc, (void**) &best_pn->parse_node.globals);
        new_pn = add_PNode(p, 0, &p->user.loc, best_loc.s, best_pn, 0, 0, 0);
        new_sn = new_SNode(p,
                           best_sn->state,
                           &best_loc,
                           new_pn->initial_scope,
                           new_pn->initial_globals);
        ref_pn(new_pn);
        new_sn->last_pn = new_pn;
        set_add_znode(&new_sn->zns, (z = new_ZNode(p, new_pn)));
        vec_add(&z->sns, best_sn);
        ref_sn(best_sn);
        r->znode = z;
        ref_sn(new_sn);
        r->snode = new_sn;
        r->reduction = rr;
        r->new_snode = NULL;
        r->next = NULL;
        free_old_nodes(p);
        free_old_nodes(p);
        reduce_one(p, r);
        for (i = 0; i < p->snode_hash.m; i++)
            for (sn = p->snode_hash.v[i]; sn; sn = sn->bucket_next)
                for (j = 0; j < sn->zns.n; j++)
                    if ((z = sn->zns.v[j]))
                        if (z->pn->reduction == rr)
                        {
                            z->pn->evaluated = 1;
                            z->pn->error_recovery = 1;
                        }
        if (p->shifts_todo || p->reductions_todo)
            res = 0;
    }
    FREE(q);
    return res;
}

#define PASS_CODE_FOUND(_p, _pn)                                             \
    ((_pn)->reduction && (_pn)->reduction->npass_code > (_p)->index &&       \
     (_pn)->reduction->pass_code[(_p)->index])

static void pass_call(Parser* p, D_Pass* pp, PNode* pn)
{
    if (PASS_CODE_FOUND(pp, pn))
        pn->reduction->pass_code[pp->index](pn,
                                            (void**) &pn->children.v[0],
                                            pn->children.n,
                                            (intptr_t) &
                                                ((PNode*) (NULL))->parse_node,
                                            (D_Parser*) p);
}

static void pass_preorder(Parser* p, D_Pass* pp, PNode* pn)
{
    int found = PASS_CODE_FOUND(pp, pn), i;
    pass_call(p, pp, pn);
    if ((pp->kind & D_PASS_FOR_ALL) ||
        ((pp->kind & D_PASS_FOR_UNDEFINED) && !found))
        for (i = 0; i < pn->children.n; i++)
            pass_preorder(p, pp, pn->children.v[i]);
}

static void pass_postorder(Parser* p, D_Pass* pp, PNode* pn)
{
    int found = PASS_CODE_FOUND(pp, pn), i;
    if ((pp->kind & D_PASS_FOR_ALL) ||
        ((pp->kind & D_PASS_FOR_UNDEFINED) && !found))
        for (i = 0; i < pn->children.n; i++)
            pass_postorder(p, pp, pn->children.v[i]);
    pass_call(p, pp, pn);
}

void d_pass(D_Parser* ap, D_ParseNode* apn, int pass_number)
{
    PNode* pn = D_ParseNode_to_PNode(apn);
    Parser* p = (Parser*) ap;
    D_Pass* pp;

    if (pass_number >= p->t->npasses)
        d_fail("bad pass number: %d\n", pass_number);
    pp = &p->t->passes[pass_number];
    if (pp->kind & D_PASS_MANUAL)
        pass_call(p, pp, pn);
    else if (pp->kind & D_PASS_PRE_ORDER)
        pass_preorder(p, pp, pn);
    else if (pp->kind & D_PASS_POST_ORDER)
        pass_postorder(p, pp, pn);
}

static int exhaustive_parse(Parser* p, int state)
{
    Reduction* r;
    char *pos, *epos = NULL;
    PNode *pn, tpn;
    SNode* sn;
    ZNode* z;
    int progress = 0, ready = 0;
    d_loc_t loc;

    pos = p->user.loc.ws = p->user.loc.s = p->start;
    loc = p->user.loc;
    p->user.initial_white_space_fn(
        (D_Parser*) p, &loc, &p->user.initial_globals);
    /* initial state */
    sn = add_SNode(
        p, &p->t->state[state], &loc, p->top_scope, p->user.initial_globals);
    memset(&tpn, 0, sizeof(tpn));
    tpn.parse_node.white_space = p->user.initial_white_space_fn;
    tpn.parse_node.globals = p->user.initial_globals;
    tpn.initial_scope = tpn.parse_node.scope = p->top_scope;
    tpn.parse_node.end = loc.s;
    if (sn->last_pn)
        unref_pn(p, sn->last_pn);
    pn = add_PNode(p, 0, &loc, loc.s, &tpn, 0, 0, 0);
    ref_pn(pn);
    sn->last_pn = pn;
    set_add_znode(&sn->zns, (z = new_ZNode(p, pn)));
    while (1)
    {
        /* reduce all */
        while (p->reductions_todo)
        {
            pos = p->reductions_todo->snode->loc.s;
            if (p->shifts_todo && p->shifts_todo->snode->loc.s < pos)
                break;
            if (pos > epos)
            {
                epos = pos;
                free_old_nodes(p);
            }
            for (; (r = p->reductions_todo) && r->snode->loc.s == pos;)
            {
                p->reductions_todo = p->reductions_todo->next;
                reduce_one(p, r);
            }
        }
        /* done? */
        if (!p->shifts_todo)
        {
            if (p->accept &&
                (p->accept->loc.s == p->end || p->user.partial_parses))
                return 0;
            else
            {
                if (error_recovery(p))
                    return 1;
                continue;
            }
        }
        else if (!p->user.dont_compare_stacks && p->shifts_todo->next)
            cmp_stacks(p);
        /* shift all */
        pos = p->shifts_todo->snode->loc.s;
        if (pos > epos)
        {
            epos = pos;
            free_old_nodes(p);
        }
        progress++;
        ready = progress > p->user.commit_actions_interval;
        if (ready && !p->shifts_todo->next && !p->reductions_todo)
        {
            commit_stack(p, p->shifts_todo->snode);
            ready = progress = 0;
        }
        shift_all(p, pos);
        if (ready && p->reductions_todo && !p->reductions_todo->next)
        {
            commit_stack(p, p->reductions_todo->snode);
            progress = 0;
        }
    }
}

/* doesn't include nl */
char _wspace[256] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 /* zero padded */
};

#define wspace(_x) (_wspace[(unsigned char) _x])

static void white_space(D_Parser* p, d_loc_t* loc, void** p_user_globals)
{
    int rec = 0;
    char *s = loc->s, *scol = 0;

    if (*s == '#' && loc->col == 0)
    {
    Ldirective:
    {
        char* save = s;
        s++;
        while (wspace(*s))
            s++;
        if (!strncmp("line", s, 4))
        {
            if (wspace(s[4]))
            {
                s += 5;
                while (wspace(*s))
                    s++;
            }
        }
        if (isdigit_(*s))
        {
            loc->line = atoi(s) - 1;
            while (isdigit_(*s))
                s++;
            while (wspace(*s))
                s++;
            if (*s == '"')
                loc->pathname = s;
        }
        else
        {
            s = save;
            goto Ldone;
        }
    }
        while (*s && *s != '\n')
            s++;
    }
Lmore:
    while (wspace(*s))
        s++;
    if (*s == '\n')
    {
        loc->line++;
        scol = s + 1;
        s++;
        if (*s == '#')
            goto Ldirective;
        else
            goto Lmore;
    }
    if (s[0] == '/')
    {
        if (s[1] == '/')
        {
            while (*s && *s != '\n')
            {
                s++;
            }
            goto Lmore;
        }
        if (s[1] == '*')
        {
            s += 2;
        LnestComment:
            rec++;
        LmoreComment:
            while (*s)
            {
                if (s[0] == '*' && s[1] == '/')
                {
                    s += 2;
                    rec--;
                    if (!rec)
                        goto Lmore;
                    goto LmoreComment;
                }
                if (s[0] == '/' && s[1] == '*')
                {
                    s += 2;
                    goto LnestComment;
                }
                if (*s == '\n')
                {
                    loc->line++;
                    scol = s + 1;
                }
                s++;
            }
        }
    }
Ldone:
    if (scol)
        loc->col = s - scol;
    else
        loc->col += s - loc->s;
    loc->s = s;
    return;
}

void null_white_space(D_Parser* p, d_loc_t* loc, void** p_globals)
{
}

D_Parser* new_D_Parser(D_ParserTables* t, int sizeof_ParseNode_User)
{
    Parser* p = MALLOC(sizeof(Parser));
    memset(p, 0, sizeof(Parser));
    p->t = t;
    p->user.loc.line = 1;
    p->user.sizeof_user_parse_node = sizeof_ParseNode_User;
    p->user.commit_actions_interval = DEFAULT_COMMIT_ACTIONS_INTERVAL;
    p->user.syntax_error_fn = syntax_error_report_fn;
    p->user.ambiguity_fn = ambiguity_abort_fn;
    p->user.error_recovery = 1;
    p->user.save_parse_tree = t->save_parse_tree;
    if (p->t->default_white_space)
        p->user.initial_white_space_fn = p->t->default_white_space;
    else if (p->t->whitespace_state)
        p->user.initial_white_space_fn = parse_whitespace;
    else
        p->user.initial_white_space_fn = white_space;
    return (D_Parser*) p;
}

void free_D_Parser(D_Parser* ap)
{
    Parser* p = (Parser*) ap;
    if (p->top_scope && !p->user.initial_scope)
        free_D_Scope(p->top_scope, 0);
    if (p->whitespace_parser)
        free_D_Parser((D_Parser*) p->whitespace_parser);
    FREE(ap);
}

void free_D_ParseNode(D_Parser* p, D_ParseNode* dpn)
{
    if (dpn != NO_DPN)
    {
        unref_pn((Parser*) p, DPN_TO_PN(dpn));
        free_parser_working_data((Parser*) p);
    }
#ifdef TRACK_PNODES
    if (((Parser*) p)->xall)
        printf("tracked pnodes\n");
#endif
}

static void copy_user_configurables(Parser* pp, Parser* p)
{
    memcpy(((char*) &pp->user.start_state) + sizeof(pp->user.start_state),
           ((char*) &p->user.start_state) + sizeof(p->user.start_state),
           ((char*) &pp->user.syntax_errors - (char*) &pp->user.start_state));
}

Parser* new_subparser(Parser* p)
{
    Parser* pp = (Parser*) new_D_Parser(p->t, p->user.sizeof_user_parse_node);
    copy_user_configurables(pp, p);
    pp->end = p->end;
    pp->pinterface1 = p->pinterface1;
    alloc_parser_working_data(pp);
    return pp;
}

static void initialize_whitespace_parser(Parser* p)
{
    if (p->t->whitespace_state)
    {
        p->whitespace_parser = new_subparser(p);
        p->whitespace_parser->user.initial_white_space_fn = null_white_space;
        p->whitespace_parser->user.error_recovery = 0;
        p->whitespace_parser->user.partial_parses = 1;
        p->whitespace_parser->user.free_node_fn = p->user.free_node_fn;
    }
}

static void free_whitespace_parser(Parser* p)
{
    if (p->whitespace_parser)
    {
        free_D_Parser((D_Parser*) p->whitespace_parser);
        p->whitespace_parser = 0;
    }
}

static PNode* handle_top_level_ambiguities(Parser* p, SNode* sn)
{
    int i;
    ZNode* z = 0;
    PNode *pn = NULL, *last = NULL, *x;
    for (i = 0; i < sn->zns.n; i++)
    {
        if (sn->zns.v[i])
        {
            x = sn->zns.v[i]->pn;
            LATEST(p, x);
            if (!pn)
            {
                z = sn->zns.v[i];
                pn = x;
            }
            else
            {
                if (x != pn && !x->ambiguities && x != last)
                {
                    x->ambiguities = pn->ambiguities;
                    ref_pn(x);
                    pn->ambiguities = x;
                    if (!last)
                        last = x;
                }
                free_ZNode(p, sn->zns.v[i], sn);
            }
        }
    }
    sn->zns.v[0] = z;
    sn->zns.n = 1;
    sn->zns.i = 0;
    return pn;
}

D_ParseNode* dparse(D_Parser* ap, char* buf, int buf_len)
{
    int r;
    Parser* p = (Parser*) ap;
    SNode* sn;
    PNode* pn;
    D_ParseNode* res = NULL;

    p->states = p->scans = p->shifts = p->reductions = p->compares = 0;
    p->start = buf;
    p->end = buf + buf_len;

    initialize_whitespace_parser(p);
    alloc_parser_working_data(p);
    if (p->user.initial_scope)
        p->top_scope = p->user.initial_scope;
    else
    {
        if (p->top_scope)
            free_D_Scope(p->top_scope, 0);
        p->top_scope = new_D_Scope(NULL);
        p->top_scope->kind = D_SCOPE_SEQUENTIAL;
    }
    r = exhaustive_parse(p, p->user.start_state);
    if (!r)
    {
        sn = p->accept;
        if (sn->zns.n != 1)
            pn = handle_top_level_ambiguities(p, sn);
        else
            pn = sn->zns.v[0]->pn;
        pn = commit_tree(p, pn);
        if (d_verbose_level)
        {
            printf("%d states %d scans %d shifts %d reductions "
                   "%d compares %d ambiguities\n",
                   p->states,
                   p->scans,
                   p->shifts,
                   p->reductions,
                   p->compares,
                   p->ambiguities);
            if (p->user.save_parse_tree)
            {
                if (d_verbose_level > 1)
                    xprint_paren(p, pn);
                else
                    print_paren(p, pn);
                printf("\n");
            }
        }
        if (p->user.save_parse_tree)
        {
            ref_pn(pn);
            res = &pn->parse_node;
        }
        else
            res = NO_DPN;
        unref_sn(p, p->accept);
        p->accept = NULL;
    }
    else
        p->accept = NULL;
    free_parser_working_data(p);
    free_whitespace_parser(p);
    return res;
}
