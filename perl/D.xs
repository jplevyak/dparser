/* 
 * $Id: D.xs,v 1.1.1.1 2010-05-27 15:29:30 cmont Exp $ 
 *
 * $Log: D.xs,v $
 * Revision 1.1.1.1  2010-05-27 15:29:30  cmont
 * the da-parser with perl module
 *
 *
 */

#include "Dxs.c"

#
#
#
#
#
#
#
#
#
# 

MODULE = Parser::D        PACKAGE = D_ParserTablesPtr PREFIX = tables_

void
tables_free(p)
D_ParserTables* p
CODE:
  warn("==free tbl@%x", p);
  // creates havocs... at final global release
  // must have been already freed? but where?
  //FREE(p);


SV*
tables_dump(dpt)
D_ParserTables* dpt
PREINIT:
  STRLEN count_charPtrPtr = 0x001a;
CODE:
  RETVAL = newSVpvn((char*)dpt, count_charPtrPtr);
OUTPUT:
  RETVAL


char*
tables_symbol_name(dpt, i)
D_ParserTables* dpt
int i
CODE:
	warn("==table_symbol_string get");
        RETVAL = dpt->symbols[i].name;
OUTPUT:
	RETVAL


MODULE = Parser::D        PACKAGE = Parser::D::Tables PREFIX = tables_


D_ParserTables*
tables_read_binary(tables_name)
     char* tables_name
CODE:
     RETVAL = read_binary_tables(tables_name, NULL, NULL);
OUTPUT:
     RETVAL



D_ParserTables*
tables_read_binary_from_file(tables_name)
FILE* tables_name
CODE:
        RETVAL = read_binary_tables_from_file(tables_name,  NULL, NULL);
OUTPUT:
	RETVAL


D_ParserTables*
tables_read_binary_from_string(tables_name)
     unsigned char* tables_name
CODE:
     RETVAL = read_binary_tables_from_string(tables_name,  NULL, NULL);
OUTPUT:
	RETVAL




#
#
# d_loc_t
#
#
#
#
#
###################################################################
MODULE = Parser::D        PACKAGE = Parser::D::d_loc_t  PREFIX = d_loc_t_
PROTOTYPES: ENABLE

STRLEN
d_loc_t_s_get(s)
HV* s
PREINIT:
	d_loc_t* loc;
	char* buf_start;
CODE:
	loc = INT2PTR(d_loc_t*, SvIV(SvRV(*__hvSV(s, this))));
	buf_start = SvPV_nolen(SvRV(*hv_fetch(s, "buf", 3, 0)));
	RETVAL = loc->s - buf_start;		
	if(loc->s == NULL || RETVAL > 0x8fffffff) {
	  warn("<=d_loc_t_s_get::ERROR::\t\tloc@%x pos=(loc.s%x - buf%x)%x:\n"
	       , loc, loc->s, buf_start, RETVAL);
	  RETVAL = 0; 
	}
OUTPUT:
	RETVAL



STRLEN
d_loc_t_s_set(s, l)
HV* s
STRLEN l
PREINIT:
	d_loc_t* loc;
	char* buf_start;
CODE:
	loc = INT2PTR(d_loc_t*, SvIV(SvRV(*__hvSV(s, this))));
	buf_start = SvPV_nolen(SvRV(*__hvSV(s, buf)));
	loc->s = buf_start + l;
	DBG2(warn("==d_loc_t_s_set\t\ts-buf@%x=(loc.s*%x - buf*%x):\n", loc, loc->s, buf_start));
	RETVAL = l;
OUTPUT:
	RETVAL


int
d_loc_t_col_get(s)
HV* s
PREINIT:
	d_loc_t* loc;
CODE:
	loc = INT2PTR(d_loc_t*, SvIV(SvRV(*__hvSV(s, this))));
	DBG2(warn("==d_loc_t_s_get\t\ts-buf@%x=(loc.s*%x)\n", loc, loc->s));
	RETVAL = loc->col;
OUTPUT:
	RETVAL


int
d_loc_t_line_get(s)
HV* s
PREINIT:
	d_loc_t* loc;
CODE:
	loc = INT2PTR(d_loc_t*, SvIV(SvRV(*__hvSV(s, this))));
	RETVAL = loc->line;
OUTPUT:
	RETVAL

      


#
#
# Parse NODE Pointer
#
#
# ->user
# ->global
#
###################################################################
MODULE = Parser::D        PACKAGE = D_ParseNodePtr   PREFIX = dpn_
PROTOTYPES: ENABLE

SV*
dpn_children_list(dpn)
D_ParseNode* dpn
PREINIT:
	PNode* pn;
CODE:
	pn = D_ParseNode_to_PNode(dpn);
	RETVAL = make_pnode_list(&(pn->children.v[0]), d_get_number_of_children(dpn));
OUTPUT:
	RETVAL




SV*
dpn_user(pn, ...)
CASE: items == 2
D_ParseNode* pn
PREINIT:
	SV* val;
CODE:
	val = SvREFCNT_inc(ST(1));
        pn->user.pl = newSVsv(val);
        RETVAL = val;
	DBG(3, warn("<=dpn_user put\t\t\tdpn@%x user*%x<#%i\n"
			, pn, pn->user.pl, SvREFCNT(pn->user.pl)));
OUTPUT:
	RETVAL
CASE:
D_ParseNode* pn
CODE:
	DBG(3, warn("=>dpn_user get\t\t\tdpn@%x user*%x\n", pn, pn->user.pl));
        if(pn->user.pl == Nullsv) {
	  XSRETURN_UNDEF;
	} else {
	  /*fails with SvRV no_inc newSV SvREFCNT_inc
	   * newRV refers itself!
	   * in fact RV(pn->user.pl) mortalises and when goes out of scope
	   * of ::Table.. it would disappears!
	   */
	  RETVAL = newSVsv(pn->user.pl);
	  DBG(1, warn("<=dpn_user get\t\t\tdpn@%x user@%x<#%i~@%x\n"
		   , pn, pn->user.pl, SvREFCNT(pn->user.pl), RETVAL)
	      );
	}
OUTPUT:
	RETVAL


int
dpn_action_index(dpn)
D_ParseNode* dpn
PREINIT:
	D_Reduction* r;
CODE:
	r = D_ParseNode_to_PNode(dpn)->reduction;
	if(r) {
	  if(r->action_index >= 0) {
	    RETVAL = r->action_index;
	  } else {
	    RETVAL = (unsigned int)r->final_code + (unsigned int)r->speculative_code;
	  }
	} else {
	  RETVAL = -1;
	}
OUTPUT:
	RETVAL

int
dpn_speculative_code(dpn)
D_ParseNode* dpn
PREINIT:
	D_Reduction* r;
CODE:
	r = D_ParseNode_to_PNode(dpn)->reduction;
	if(r) {
	  RETVAL = (unsigned int)r->speculative_code;
	} else {
	  RETVAL = -1;
	}
OUTPUT:
	RETVAL

int
dpn_final_code(dpn)
D_ParseNode* dpn
PREINIT:
	D_Reduction* r;
CODE:
	r = D_ParseNode_to_PNode(dpn)->reduction;
	if(r) {
	  RETVAL = (unsigned int)r->final_code;
	} else {
	  RETVAL = -1;
	}
OUTPUT:
	RETVAL


int
dpn_symbol(pn, ...)
CASE: items == 2
D_ParseNode* pn
PREINIT:
	int val = (int)SvIV(ST(1));
CODE:
	DBG(1, warn("==dpn_symbol put\n"));
	SvREFCNT_dec(pn->symbol);
        pn->symbol = val;
	RETVAL = val;
OUTPUT:
	RETVAL
CASE:
D_ParseNode* pn
CODE:
	DBG(1, warn("==dpn_symbol get"));
	RETVAL = pn->symbol;
OUTPUT:
	RETVAL



SV*
dpn_val(dpn)
D_ParseNode* dpn
PREINIT:
	char*	start;
	char*	end;
	STRLEN 	len;
CODE:
	start 	= dpn->start_loc.s;
	end 	= dpn->end;
	len 	= end - start;
	DBG(1, warn("==dpn_val get"));
        if(len > 0) {
	  RETVAL = newSVpv(start, len);
	} else {
	  XSRETURN_UNDEF;
	}
OUTPUT:
	RETVAL


SV*
dpn_globals(pn, ...)
CASE: items == 2
D_ParseNode* pn
PREINIT:
	SV* val = SvREFCNT_inc(ST(1));
CODE:
        pn->globals = newSVsv(val);
	RETVAL = val;
	DBG(1, warn("==dpn_globals put\t\tdpn@%x=(globals*%x<#%d)\n", pn, pn->globals, SvREFCNT(pn->globals)));
OUTPUT:
	RETVAL
CASE:
D_ParseNode* pn
SV* val = NO_INIT
CODE:
	RETVAL = newSVsv(pn->globals);
	DBG(1, warn("==dpn_globals get\t\tdpn@%x=(globals*%x<#%d)\n", pn, pn->globals, SvREFCNT(pn->globals)));
OUTPUT:
	RETVAL



int
dpn_d_get_number_of_children(dpn)
D_ParseNode* dpn
CODE:
  RETVAL = d_get_number_of_children(dpn);
OUTPUT:
  RETVAL


#d_get_child
#
#
#
#
###################################################################
MODULE = Parser::D         PACKAGE = ParserPtr  PREFIX = dparser_
PROTOTYPES: ENABLE

d_loc_t*
dparser_loc(p, ...)
CASE: items == 2
  Parser* p
PREINIT:
  SV* val = ST(1);
CODE:
	DBG(1, warn("==loc_set\t\t\t\tp@%x=val=%x\n", p, val));
	StructCopy(INT2PTR(d_loc_t*, SvIV(val)), &(p->user.loc), d_loc_t);
	RETVAL = &(p->user.loc);
OUTPUT:
  RETVAL
CASE:
  Parser* p
CODE:
  DBG(1, warn("==loc_get\t\t\t\tp@%x~@%x(<#%i)\n"
	      , p, d_pl_interface(p), d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1
	      )
      );
  RETVAL = &(p->user.loc);
OUTPUT:
  RETVAL


int
dparser_syntax_errors(p, ...)
CASE: items == 2
Parser* p
PREINIT:
  int val;
CODE:
	val = (int)SvIV(ST(1));
	DBG(1, warn("=>syntax_errors_set\t\tp@%x=%ld\n", p, p));
  p->user.syntax_errors = val;
  RETVAL = val;
OUTPUT:
  RETVAL
CASE:
Parser* p
CODE: 
  DBG(1, warn("=>syntax_errors_get\t\t\tp@%x=%d\n", p, p->user.syntax_errors));
  RETVAL = p->user.syntax_errors;
OUTPUT:
  RETVAL



void
dparser_free_D_Parser(p)
Parser* p
PREINIT:
	int i;
CODE:
	i = d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1;
  if(i < 0 || i > 4 || d_debug_level > 2) {
    warn("=>free_D_Parser\t\t\t\tp@%x~@%x(<#%i)\n", p, d_pl_interface(p), i);
  }
  if(i >= 0) {
    /* yeaky casting...check in parser.c!
     * opposite of dparser_make(); (new_D_Parser)...
     * actually only free is count is low!
     */
    SvREFCNT_dec(d_pl_interface(p));
    /* this has been a sub-parser.
     * it will be free when USE_GC is defined.
     * check free_D_Parser()
     */
  } else {
    /* shall never happen since this function is called when 
     * p-interface exists.
     */
  }



SV*
dparser_interface(p)
Parser* p
CODE:
	DBG(1, warn("==dparser_interface\t\t\tp@%x~@%x(<#%i)\n"
	   , p, d_pl_interface(p), d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1));
	RETVAL = SvREFCNT_inc(d_pl_interface(p));
OUTPUT:
	RETVAL



D_ParserTables*
dparser_tables(p)
Parser* p
CODE:
	DBG(1, warn("==dparser_tables\t\tp@%x~@%x(<#%i)\n"
	, p, d_pl_interface(p), d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1));
  RETVAL = d_dpt(p);
OUTPUT:
  RETVAL



void
dparser_bless_interface(p)
Parser* p
PREINIT:
	SV* s_rv;
CODE:
	s_rv = d_pl_interface(p);
  if(s_rv == Nullsv) {
    warn("==dparser_bless_interface:ERROR found a Parser* without an interface?!\n");
    return;
  } else {
    Parser* p_old = INT2PTR(Parser*, SvIV(SvRV(*hv_fetch((HV*)SvRV(s_rv), "this", 4, 0))));
    if(p_old != p) {
      /* then this object needs to be duplicated?! */
      // well I do not really know!
      // but at least make a copy of the refrence RV
      // or the HV*?!
      DBG(1, warn("==dparser_bless_interface:\t\t\thv(<#%i)rv(<#%i)\n", SvREFCNT(SvRV(s_rv)), SvREFCNT(s_rv)));
      p->pinterface1 = newSVsv(s_rv);
    } else {
      SvREFCNT_inc(d_pl_interface(p));
    }
  }
	DBG(1, warn("<=dparser_bless_interface\t\t\tp@%x~@%x(<#%i)\n", p, d_pl_interface(p) \
	   , d_pl_interface(p) ? SvREFCNT(d_pl_interface(p)) : -1));



#
#
#
#
##################################################################
MODULE = Parser::D         PACKAGE = Parser::D  PREFIX = dparser_
PROTOTYPES: ENABLE

Parser*
dparser_make(s, dpt, start_symbol)
   HV* s
   D_ParserTables* dpt
   char* start_symbol
PREINIT:
	int i = 0;
	/* in fact new_D_Parser is not cast to the right structure... */
	Parser* p;
	D_Parser* dp;
CODE:
     	p = (Parser*) new_D_Parser(dpt, sizeof(D_ParseNode_User));
	dp = &p->user;
	sIVhv(dp, fixup_EBNF_productions);
   	sIVhv(dp, save_parse_tree);
   	dp->initial_scope = NULL;
	sSVhv(dp, initial_globals);	
   	sIVhv(dp, dont_fixup_internal_productions);
   	sIVhv(dp, dont_merge_epsilon_trees);
   	sIVhv(dp, commit_actions_interval);
   	sIVhv(dp, partial_parses);
   	sIVhv(dp, dont_compare_stacks);
   	sIVhv(dp, dont_use_eagerness_for_disambiguation);
        sIVhv(dp, use_greedyness_for_disambiguation);
   	sIVhv(dp, dont_use_height_for_disambiguation);
   	sIVhv(dp, error_recovery);
   	inthvIV(s, d_debug_level);
	p->pinterface1 = newRV((SV*)s);
        p->speculative_code = speculative_action;
        p->final_code = final_action;
   	dp->free_node_fn = free_node_fn;
   	dp->initial_white_space_fn = initial_white_space_fn;
   	dp->syntax_error_fn = syntax_error_fn;
   	dp->ambiguity_fn = ambiguity_fn;
	/* this is the magic of object reallocation */
  	if(*start_symbol) {
	  for(i = 0; i < dpt->nsymbols; i++) {
	    if(dpt->symbols[i].kind == D_SYMBOL_NTERM
	       && strcmp(dpt->symbols[i].name, start_symbol) == 0) {
	      dp->start_state = dpt->symbols[i].start_symbol;
	      break;
	    }
	  }
	  if(i == dpt->nsymbols) {
	    warn("<=make\t\t\tinvalid start symbol@x%lx[#%d]:%s\n", dpt, i, start_symbol);
	  }
	}
        /*TODO remap also actions indexes here ? */
   	RETVAL = p;
OUTPUT:
   	RETVAL


char*
dparser_version()
PREINIT:
    char v[0x10];
CODE:
    d_version(v);
    RETVAL = v;
 OUTPUT:
    RETVAL



D_ParseNode*
dparser_dparse(s, i, l)
HV* s
int i
STRLEN l
PREINIT:
	Parser* p;
	char* buf;
CODE:
	p = INT2PTR(Parser*, SvIV(SvRV(*hv_fetch(s, "this", 4, 0))));
	buf = SvPV_nolen(SvRV(*hv_fetch(s, "buf_start", 9, 0)));
        d_verbose_level = SvIV(*hv_fetch(s, "d_verbose_level", sizeof("d_verbose_level") - 1, 1));
	DBG(1, warn("==dparse\t\t\t\tp@%x s@%x:%s l=%d\n",p,buf+i,buf+i,l));
	RETVAL = dparse((D_Parser*)p, buf+i, l);
OUTPUT:
  RETVAL







##################################################################
#
# Grammar related packages
# with 
# -its own interface updating C-code values from Perl modules defines
# - 
#

MODULE = Parser::D   PACKAGE = GrammarPtr  PREFIX = g_


void
g_register_fatal(fn)
SV *    fn
CODE:
         /* Remember the Perl sub */
         if (exit_callback == (SV*)NULL)
           exit_callback = newSVsv(fn) ;
         else
           SvSetSV(exit_callback, fn) ;
         /* register the callback with the external library */
/* int i = atexit(exit_cb1) ;*/



void
g_free_D_Grammar(g)
Grammar* g
CODE:
	DBG(1, warn("==free_D_Grammar\t\t\tg@%x*%x\n", g, *g));
        free_D_Grammar(g);

void
g_print_rdebug_grammar(g,p)
Grammar* g
char*    p
CODE:
	print_rdebug_grammar(g,p);



Grammar*
g_new_D_Grammar(grammar_pathname)
char* grammar_pathname
CODE:
	RETVAL = new_D_Grammar(grammar_pathname);
	DBG(1, warn("==new_D_Grammar\t\t\t\tg@%x*%x\n", RETVAL, *RETVAL));
OUTPUT:
	RETVAL


SV*
g_write_binary_tables_to_string(g)
Grammar* g
PREINIT:
	unsigned char* str;
	STRLEN str_len;
	int i;
CODE:
	i = write_binary_tables_to_string(g, &str, &str_len);
	RETVAL = newSVpvn((char*)str, str_len * sizeof(unsigned char));
OUTPUT:
	RETVAL


int
g_write_binary_tables_to_file(g,fp)
Grammar* g
FILE*    fp
CODE:
	RETVAL = write_binary_tables_to_file(g, fp);
OUTPUT:
	RETVAL


int
g_write_binary_tables(g)
Grammar* g
CODE:
	RETVAL = write_binary_tables(g);
OUTPUT:
	RETVAL

int
g_write_c_tables(g)
Grammar* g
CODE:
	RETVAL = write_c_tables(g);
OUTPUT:
	RETVAL


void
g_mkdparse(g, grammar_pathname)
Grammar* g
char* grammar_pathname
CODE:
	mkdparse(g, grammar_pathname);

void
g_mkdparse_from_string(g, s)
Grammar* g
char* s
CODE:
	mkdparse_from_string(g, s);




#
# XS functions to link the
# Perl Object Parser::D::Gammar to its C conterpart.
#
MODULE = Parser::D   PACKAGE = Parser::D::Gammar  PREFIX = g_


#
# FUNCTION: update_constantes
#
# is a pre-hook to link global variables used in grammar
# and Parser::D::Gammar. a must one off do to initialse the perl object.
# This is however a one way link. those attributes are not fed back to 
# the C object (at destruction).
#
#
# INPUT:
#
# HV* is the new blessed class object.
# Grammar* is the C grammar object to be linked with.
#
void
g_update_constantes(s,g)
HV* s
Grammar* g
CODE:
	/* grammar construction options */
	IV_2_g(states_for_whitespace);
	IV_2_g(states_for_all_nterms);
	IV_2_g(set_op_priority_from_rule);
	IV_2_g(right_recursive_BNF);
	IV_2_g(tokenizer);
	IV_2_g(longest_match);
	/* grammar writing options */
	cpyPVhv(g,grammar_ident);
	cpyPVhv(g,write_extension);
	IV_2_g(scanner_blocks);
	IV_2_g(scanner_block_size);
	IV_2_g(write_line_directives);
	IV_2_g(write_header);
	IV_2_g(token_type);
	/* don't print anything to stdout, when the grammar is printed there */
        d_verbose_level = SvIV(*hv_fetch(s, "d_verbose_level", sizeof("d_verbose_level") - 1, 1));
        d_rdebug_grammar_level = SvIV(*hv_fetch(s, "d_rdebug_grammar_level", sizeof("d_rdebug_grammar_level") - 1, 1));
	if (d_rdebug_grammar_level > 0) d_verbose_level = 0;
        //# no cant do that it has been set up in new_D_grammar anyway...
        //#PV_2_g(pathname);
	

# emacs stuff
#;;; Local Variables: ***
#;;; mode:c ***
#;;; End: ***
