/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#ifndef GRAMGRAM_H
#define GRAMGRAM_H

#ifdef __cplusplus
extern "C" {
#endif

struct Production;
struct Rule;
struct Elem;

typedef struct ParseNode_User
{
    struct Production* p;
    struct Rule* r;
    struct Elem* e;
    unsigned int kind;
} ParseNode_User;

#define D_ParseNode_User ParseNode_User

#define D_ParseNode_Globals struct Grammar

#ifdef __cplusplus
}
#endif

#endif  // GRAMGRAM_H
