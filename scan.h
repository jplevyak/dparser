/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#ifndef SCAN_H
#define SCAN_H

#ifdef __cplusplus
extern "C" {
#endif

#include "d.h"

typedef struct ShiftResult
{
    struct SNode* snode;
    D_Shift* shift;
    d_loc_t loc;
} ShiftResult;

int scan_buffer(d_loc_t* loc, D_State* st, ShiftResult* result);

#ifdef __cplusplus
}
#endif

#endif  // SCAN_H
