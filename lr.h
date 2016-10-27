/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#ifndef LR_H
#define LR_H

#ifdef __cplusplus
extern "C" {
#endif

void build_LR_tables(Grammar* g);
void sort_VecAction(VecAction* v);
uint elem_symbol(Grammar* g, Elem* e);
State* goto_State(State* s, Elem* e);
void free_Action(Action* a);

#ifdef __cplusplus
}
#endif

#endif // LR_H
