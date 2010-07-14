/* $Id$
 *
 * $Log$
 *
 */
#if ! defined __DXS_H__
#define __DXS_H__

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


struct Production;
struct Rule;
struct Elem;

typedef union {
  struct gramgram_s {
    struct 	Production *p;
    struct 	Rule *r;
    struct 	Elem *e;
    unsigned int 	kind;
  } g;
  SV* pl;
  struct pythongram_s {
    void* t; 
    void* s;
    int inced_global_state;
  } py;
} D_ParseNode_User_t;

#define D_ParseNode_User D_ParseNode_User_t
#define D_ParseNode_Globals struct Grammar
#undef  D_ParseNode_Globals
#define D_ParseNode_Globals SV

#include "d.h"

#define D_ParseNode_to_PNode(_apn) \
((PNode*)D_PN(_apn, -(int)&((PNode*)(NULL))->parse_node))

#define PNode_to_D_ParseNode(_apn) \
((D_ParseNode*)&((PNode*)(_apn))->parse_node)


// I am not sure of how to handling references counters...!
#define d_pl_interface(_p) (SV*)((Parser*)_p)->pinterface1
#define d_dpt(_p) (_p)->t



static SV* make_plobject_from_node(Parser*, D_ParseNode*);


/* my great macros */
#define __hvSV(_h_,_n_) hv_fetch(_h_, #_n_, sizeof(#_n_)-1, 0)
#define __rvSV(_h_,_n_) __hvSV((HV*)SvRV(_h_),_n_)
#define _rvSV(_h_,_n_) *__rvSV(_h_,_n_)

#define t_rv(_t_,_h_,_n_) do						\
    { SV** sv_pp = __rvSV(_h_,_n_);					\
      _n_ = _t_ (sv_pp != (SV**)NULL					\
		 ? (SvROK(*sv_pp)					\
		    ? SvRV(*sv_pp)					\
		    : *sv_pp						\
		    )							\
		 : &PL_sv_undef						\
		 );							\
    } while(0)

#define t_rvIV(_h_,_n_) do						\
    { SV** sv_pp = __rvSV(_h_,_n_);					\
      _n_ = (sv_pp != (SV**)NULL					\
	     ? SvIV(*sv_pp)						\
	     : 0);							\
    } while(0)


      //warn("sv_pp@%x ", *sv_pp);					\

#define rvSV(_h_,_n_) _n_ = _rvSV(_h_,_n_)
#define rvHV(_h_,_n_) _n_ = (HV*)_rvSV(_h_,_n_)
#define rvAV(_h_,_n_) _n_ = (AV*)SvRV(_rvSV(_h_,_n_))
#define rvIV(_h_,_n_) _n_ = SvIV(_rvSV(_h_,_n_))

#define IV_2_g(_n_)      g->_n_ = SvIV(*hv_fetch(s, #_n_, sizeof(#_n_)-1, 0))
#define PV_2_g(_n_)      g->_n_ = SvPV_nolen(*hv_fetch(s, #_n_, sizeof(#_n_)-1, 0))
#define cpyPVhv(_s_,_n_) strcpy(_s_->_n_, SvPV_nolen(*hv_fetch(s, #_n_, sizeof(#_n_)-1, 0)))

#define sSVhv(_s_,_n_) _s_->_n_ = *__hvSV(s,_n_)
#define sIVhv(_s_,_n_) _s_->_n_ = SvIV(*__hvSV(s,_n_))
#define IVhv(_s_,_n_) sIVhv(_s_,_n_)



//SvIV(*hv_fetch(s, #_n_, sizeof(#_n_)-1, 0))

#define inthvIV(_h_,_n_) _n_ = SvIV(*__hvSV(_h_,_n_))



#undef  DBG
#ifdef D_DEBUG
#define DBG(_i,_x) if(d_debug_level > (_i) ) { _x ;}
#else
#define DBG(_i,_x)
#endif
#define DBG2(_x) DBG(2,_x)





#endif
