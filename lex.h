/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#ifndef LEX_H
#define LEX_H

#ifdef __cplusplus
extern "C" {
#endif

/* #define LIVE_DIFF_IN_TRANSITIONS */

struct Grammar;

typedef struct ScanStateTransition
{
    uint index;
    VecAction live_diff;
    VecAction accepts_diff;
} ScanStateTransition;

typedef struct ScanState
{
    uint index;
    struct ScanState* chars[256];
    VecAction accepts;
    VecAction live;
    ScanStateTransition* transition[256];
} ScanState;

void build_scanners(struct Grammar* g);

#ifdef __cplusplus
}
#endif

#endif // LEX_H
