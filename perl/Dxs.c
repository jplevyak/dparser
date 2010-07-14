/* 
 * $Id$ 
 *
 * $Log$
 *
 */

/* Copyright (c) 2006,2007  SHARP */


#include "Dxs.h"


/* Make a pointer value string */

//#define D_MAJOR_VERSION 1
//#define D_MINOR_VERSION 14
//#define D_BUILD_VERSION 0
#include "version.c"

/*
 * returns a perl array of pointer D_ParseNode* objects from array of PNode*
 * mostly needed for building children list used by the actions
 */
static SV*
make_pnode_list(PNode** pn_p, int nc) {
  int i;
  SV** r;
  AV* list = newAV();
  if(nc) {
    DBG2(warn("=>make_pnode_list\t\tpn_p[0]@%x children#%i\n", *pn_p, nc));
  }
  for(i = 0; i < nc; i++) {
    D_ParseNode* dpn = PNode_to_D_ParseNode(*(pn_p + i));
    SV* dpnp = sv_setref_pv(newSV(0), "D_ParseNodePtr", (void*)dpn);
    r = av_store(list, i, dpnp);
    if(r == (SV**) NULL) {
      warn("==make_pnode_list::can't store pl_node@%x<(#%i)[%i]", dpnp, SvREFCNT(dpnp), i);
      break;
    }
  }
  return newRV((SV*)list);
}

/*
 * Transpose a sequence of D_ParseNode pointers into a perl list
 */

static SV*
make_dpnode_list(D_ParseNode** pn_p, int nc) {
  int i;
  SV** r;
  AV* list = newAV();
  if(nc) {
    DBG2(warn("=>make_dpnode_list\t\tpn_p[0]@%x children#%i\n", *pn_p, nc));
  }
  for(i = 0; i < nc; i++) {
    D_ParseNode* dpn = *(pn_p + i);
    SV* dpnp = sv_setref_pv(newSV(0), "D_ParseNodePtr", (void*)dpn);
    r = av_store(list, i, dpnp);
    if(r == (SV**) NULL) {
      warn("==make_dpnode_list::can't store pl_node@%x<(#%i)[%i]", dpnp, SvREFCNT(dpnp), i);
      break;
    }
  }
  return newRV((SV*)list);
}

/*
 * debug dump of the loci of a  D_ParseNode object
 */

static void
dd_info(D_ParseNode* dd, char* name, int speculative, int pdi) {
  char 	buf[0x100];
  char*	start 	= dd->start_loc.s;
  char*	end 	= dd->end_skip;
  int 	len 	= end - start;

  DBG(1, warn("==dd_info\t\t\tdpn@%x\n",dd));

  if(len > 255)
    len = 255;
  strncpy(buf, start, len);
  if(len == 255)
    buf[254] = buf[253] = buf[252] = '.';
  buf[len] = 0;
  if(!speculative || pdi != 2) {
    printf("%30s%s:\t%s\n", name, (speculative ? " ???" : "    "), buf);
  }
}

/* 
 * general action function on each node
 * here is the point where actions are executed...
 */

static int
my_action(unsigned int idx, PNode* pn
	  , PNode** children, int n_children
	  , Parser* parser
	  , int speculative) {
  D_Reduction* 	r = pn->reduction;
  int 	result = 1;

  if(SvTRUE(ERRSV)){
    STRLEN n_a;
    warn("<=my_action::PERL ERROR::%s\n", SvPV(ERRSV, n_a)) ;  
    warn("just keep returning until finished parsing.  Need a way to tell dparser to quit\n");
    return result;
  }
  DBG(3, xpp(parser, pn));
  DBG(2, warn("=>my_action\t\t\treduction:pass_code@%x\tnpass_code=%d"
	    "\tidx%x\taction_index=%d\trule_priority=%i\top_priority=%i"
	    "\n\t\t\t\trule_assoc=%i\top_assoc=%i"
	    "\tfinal_code@%x\tspeculative_code@%x"
	    , r->pass_code, r->npass_code
	    , idx ,r->action_index, r->rule_priority, r->op_priority
	    , r->rule_assoc, r->op_assoc
	    , r->final_code, r->speculative_code
	    ));
  DBG(1,
      char	b1[0x100];
      int	i;
      strcpy(b1, "");
      for(i = 0; i < r->nelements; i++) {	
	char	b0[0x100];
	sprintf(b0
		, "[%i]=%s "
		, ((PNode*) children[i])->parse_node.symbol
		, parser->t->symbols[((PNode*) children[i])->parse_node.symbol].name
		);
	strcat(b1, b0);
      }
      warn("==my_action\t\t\tsymbol[%i]=%s<-:#%i\t%s\n"
	   , r->symbol, parser->t->symbols[r->symbol].name
	   , r->nelements
	   , b1
	   )
      );
  DBG(2,
      if(idx>2) {
	D_ParseNode* dpn = PNode_to_D_ParseNode(pn);
	char 	buf[0x20];
	char*	start 	= dpn->start_loc.s;
	char*	end 	= dpn->end_skip;
	int 	len 	= end - start;
	if(len > 0x1f)
	  len = 0x1f;
	strncpy(buf, start, len);
	buf[len] = 0;
	warn("==my_action\t\t\ttoken=%s\n", buf);
      }
      );
  DBG(4,pp(pn));
  /*
  // now it happens that, we might have an internal action to play...
  // just catch its SV*
  //.. also need g->productions.v[i]->rules.v[j]->index
  // it is offcial, -1 shall have been used when an action is local only,
  // but read table overwrites it into 0.
  // which means ${action 0} will never be done!
  *
  * well here we shall parse...
  * ParserPtr, D_ParseNodePtr, D_ParseNodePtr* 
  * the main parser: 
  * the pointer is more appropriate because this could be actually a sub parser copy.
  * the node pointer:
  * the ref-array of children pointers...
  */
  if(idx || (r->action_index >= 0)) {
    dSP;
    int i;
    SV* sv;
    /* pn_offset 
     * int pn_offset = (int)&((PNode*)(NULL))->parse_node);
     * is removed if we trust the headers 
     * are not missmatched beetween this compile
     * and the main DParser libraries...
     */
  
    D_ParseNode* dpn = PNode_to_D_ParseNode(pn);
    SV* dpnp = sv_setref_pv(newSV(0), "D_ParseNodePtr", (void*)dpn);
    SV* dpnps = make_pnode_list(children, n_children);

    ENTER ;
    SAVETMPS;
    PUSHMARK(SP);
    
    SvREFCNT_inc(d_pl_interface(parser));
    XPUSHs(sv_2mortal(sv_setref_pv(newSV(0), "ParserPtr", (void*)parser)));

    if(idx > 0) {
      sv = newSViv(idx);
    } else {
      speculative += 2; 
      sv = newSViv(r->action_index);
    }
    XPUSHs(sv_2mortal(sv));
    XPUSHs(sv_2mortal(newSViv(speculative)));
    XPUSHs(sv_2mortal(dpnp));

    /* parse also childrens, 
     * new_pn...has lots of info in it...
     * so it shall be enough
     */
    XPUSHs(sv_2mortal(dpnps));

    PUTBACK;

    i = call_method("node_action", G_SCALAR);

    SPAGAIN;
    if(i > 0) {
      result = POPi;
    }
    PUTBACK;
    FREETMPS;
    LEAVE;
  }
  DBG(1, warn("<=my_action\t\t\tresult %x\n", result));
  return result;
}

/*
 * called from D-Parser while stepping into nodes...
 * speculative actions {} are done on a token match 
 * final actions [] are done when a string of token match is securred  
 */
static int 
final_action(unsigned int idx, 
	     void *new_ps, void **children, int n_children
	     , int pn_offset, struct D_Parser *parser) {

  DBG(1, warn("=>final_action\t\t\tidx%x children#%i\t", idx, n_children));
  if(pn_offset == (int)&((PNode*)(NULL))->parse_node) {
    return my_action(idx, (PNode*) new_ps, (PNode**)children, n_children, (Parser*) parser, 0);
  } else {
    warn("<=final action : not a PNode?"
	 "\t\tpn_offset %i == macro DPN_to_PN %i\n"
	 , pn_offset, (int)&((PNode*)(NULL))->parse_node
	 );
    return 1;
  }
}

static int 
speculative_action(unsigned int idx, void *new_ps, void **children, int n_children, int pn_offset,
		      struct D_Parser *parser) {
  DBG(1, warn("=>speculative_action\t\t\tidx%x children#%i\t",idx, n_children));
  if(pn_offset ==  (int)&((PNode*)(NULL))->parse_node) {
    return my_action(idx, (PNode*) new_ps, (PNode**) children, n_children, (Parser*) parser, 1);
  } else {
    warn("<=speculative_action : not a PNode?"
	 "\t\tpn_offset %i == macro DPN_to_PN %i\n"
	 , pn_offset, (int)&((PNode*)(NULL))->parse_node
	 );
    return 1; //error
  }
}


/*
 * called from D-Paser to end an user-node
 *
 * in  free_PNode(), initialize_whitespace_parser()
 * 
 */
static void
free_node_fn(D_ParseNode* dpn) {
  int i, nc;
  if(dpn == NULL) {
    warn("==free_node_fn\t\tdpn NULL");
    return;
  }
  /* SvREFCNT(NULL) causes a crashes */
  i = dpn->globals != Nullsv ? SvREFCNT(dpn->globals) : -1;
  if(i < 0) {//would also happen because globals might not have been defined?
    warn("<=free_node_fn\t bug in pydparser.c deallocating d parser global state\n");
  } else {
    DBG(2, warn("==free_node_fn\t\tdpn@%x globals(@%x<#%i)"
	     , dpn
	     , dpn->globals
	     , i)
	);
    /*CPM070919 yo it does not work c.f. test 018.pl */
    //SvREFCNT_dec(dpn->globals);
    // it is already mortal...I expect user.pl also!
  }	  
  /* free (one layer of) children: this would be done by free_PNode itself
   * under the USE_GC regime...
   */
  DBG(0,
      i = dpn->user.pl != Nullsv ? SvREFCNT(dpn->user.pl) : -1;
      if(i >= 0) {
	warn("==free_node_fn\t\tdpn@%x"
	     " user(@%x<#%i)\n" 
	     , dpn
	     , dpn->user.pl
	     , i);
	//SvREFCNT_dec(dpn->user.pl);
      } else {
	DBG(2,warn("<=free_node_fn\tbug in pydparser.c deallocating d parser NULL user\n"));
      }
      );
}



/*
 * called by D-Parser on parsing error,
 * this is before the internal recovery error function
 */
static void 
syntax_error_fn(D_Parser* p) {
  dSP;
  DBG(1, warn("=>syntax_error_fn\t\t\tp@%x~@%x<(#%i)\n"
	   , p, d_pl_interface(p), SvREFCNT(d_pl_interface(p))));
  if(SvTRUE(ERRSV)) {
    STRLEN n_a;
    warn("=>syntax_error_fn PERL ERROR\t\tp@%x::%s\n", p, SvPV(ERRSV, n_a));
    return;
  }
  PUSHMARK(SP);
  /* here the variable does not need to be mortalised since
   * it is handled by dparser C-oject the ParserPtr (c.f. perlcall)
   */
  XPUSHs(d_pl_interface(p));
  PUTBACK ;
  call_method("syntax_error_fn", G_VOID|G_DISCARD);
  DBG(1, warn("<=syntax_error_fn\t\t\tp@%x~@%x<(#%i)\n"
	   , p, d_pl_interface(p), SvREFCNT(d_pl_interface(p))));
}

/*
 * bridge from D-Parser internal scanner, crunchify what is in between tokens.
 *
 */
static void 
initial_white_space_fn(D_Parser* p
		       , d_loc_t* loc
		       , void** p_globals
		       )
{
  dSP;
  if(SvTRUE(ERRSV)) {
    warn("==initial_white_space_fn PERL ERROR\tp@%x(@%x) loc@%x gl@%x\n",p,d_pl_interface(p),loc,*p_globals);
    return;
  }
  DBG(1, warn("=>initial_white_space_fn\t\tp@%x~@%x<(#%i) loc@%x gl@%x\n"
	   , p, d_pl_interface(p), SvREFCNT(d_pl_interface(p))
	   , loc, *p_globals));

  ENTER;
  SAVETMPS;

  PUSHMARK(SP);
  SvREFCNT_inc(d_pl_interface(p));
  XPUSHs(sv_2mortal(sv_setref_pv(newSV(0), "ParserPtr", (void*)p)));
  XPUSHs(sv_2mortal(sv_setref_pv(newSV(0), "d_loc_tPtr", (void*)loc)));
  //TODO, sort out this mistery void** globals?!
  PUTBACK;
  call_method("white_space_fn", G_VOID|G_DISCARD);

  FREETMPS;
  LEAVE;

  DBG(1, warn("<=initial_white_space_fn\t\tp@%x~@%x<(#%i) loc@%x gl@%x\n"
	   , p, d_pl_interface(p), SvREFCNT(d_pl_interface(p))
	   , loc, *p_globals));
}



/*
 * called by D-Parser when parsing branches cannot be decided upon
 * (struct D_Parser*) is really a (Parser*)
 * also  D_ParseNode** could be in effect PNode**
 */
static D_ParseNode*
ambiguity_fn(D_Parser* p
	     , int n
	     , D_ParseNode** v)
{
  dSP;
  int idx;
  SV* sv = Nullsv;
  DBG(1, warn("=>ambiguity_fn::\t\t\tp@%x~@%x(<#%i)\n"
	   , p, d_pl_interface(p), d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1
	   )
      );
  if(SvTRUE(ERRSV)) {   
    STRLEN n_a;
    warn("=>ambiguity_fn::PERL ERROR::\t\tp@%x n#%d node[0]*%x\n",p,n,*v);	
    warn("<=ambiguity_fn::PERL ERROR::%s\n", SvPV(ERRSV, n_a)) ;  
    return v[0];
  }

  ENTER;
  SAVETMPS;

  PUSHMARK(SP);
  SvREFCNT_inc(d_pl_interface(p));
  XPUSHs(sv_2mortal(sv_setref_pv(newSV(0), "ParserPtr", (void*)p)));
  XPUSHs(sv_2mortal(make_dpnode_list(v, n)));
  PUTBACK;
  
  idx = call_method("ambiguity_fn", G_SCALAR);

  if(idx > 0) {
    SPAGAIN;
    sv = SvREFCNT_inc(POPs);
    PUTBACK;
  } else {
    sv = Nullsv;
  }
  if(sv == Nullsv) {
    idx = n;
    DBG(0, warn("==ambiguity_fn::need to be returned one node index..."));
  } else {
    //NOTE: here sv_2mortal does create over deferencing ...yeak 
    idx = SvIV(sv);
  }
  if(idx >= n || idx < 0) {
    DBG(1,
	warn("<=ambiguity_fn::\t\t\tp@%x~@%x(<#%i) n#%d idx=%i\n"
	     , p
	     , d_pl_interface(p)
	     , d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1
	     , n, idx)
	);
     idx %= n;
  }

  FREETMPS;
  LEAVE;

  return v[idx];
}



/*
 * a silly function to decide if the parsing node is a branching.
 * not used anymore, until its meaning is rediscovered!
 * keep for reference
 */
int has_deeper_nodes(Parser* p, D_ParseNode* dpn) {
  int kind;
  warn("=>has_deeper_nodes\t\tp@%x~@%x(<#%i) dpn@%x\n", p, d_pl_interface(p)
       , d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1, dpn);
  kind = d_dpt(p)->symbols[dpn->symbol].kind;
  warn("<=has_deeper_nodes\t\tp@%x dpn@%x kind=%x\n", p, dpn, kind);
  return((kind == D_SYMBOL_INTERNAL) || (kind == D_SYMBOL_EBNF));
}

static SV * exit_callback = (SV*)NULL;

static void
exit_cb1()
{
  dSP;
  PUSHMARK(SP);
  /* Call the Perl sub to process the callback */
  call_sv(exit_callback, G_DISCARD) ;
}

