/*
  Copyright 2002-2004 John Plevyak, All Rights Reserved
*/

#include "d.h"

int scan_buffer(d_loc_t* aloc, D_State* parse_state, ShiftResult* results)
{
    d_loc_t loc = *aloc, last_loc = *aloc;
    char* s = loc.s;
    int col = loc.col, line = loc.line;
    int nresults = 0, i = 0, j;
    D_Shift **shift = NULL, **shift_diff = 0;

    switch (parse_state->scanner_size)
    {
        case 1:
        {
            /* all matches */
            SB_uint8* st = (SB_uint8*) parse_state->scanner_table;
            SB_trans_uint8* tst =
                (SB_trans_uint8*) parse_state->transition_table;
            uint8 state = 0, last = state, prev = state;
            uint8 c;
            uint32 sb, so;
            c = (uint8) *s++;
            while ((
                state =
                    st[state].scanner_block[(sb = (c >> SCANNER_BLOCK_SHIFT))]
                                           [(so = c & SCANNER_BLOCK_MASK)]))
            {
                state -= 1;
                if (prev && parse_state->accepts_diff)
                {
                    shift_diff =
                        parse_state
                            ->accepts_diff[tst[prev].scanner_block[sb][so]];
                    for (; *shift_diff; shift_diff++)
                    {
                        results[nresults].loc = loc;
                        results[nresults++].shift = *shift_diff;
                    }
                }
                prev = state;
                if (c == '\n')
                {
                    line++;
                    col = 0;
                }
                else
                    col++;
                loc.s = s;
                loc.line = line;
                loc.col = col;
                if (st[state].shift)
                {
                    last = state;
                    last_loc = loc;
                }
                c = (uint8) *s++;
            }
            shift = st[last].shift;
            break;
        }
        case 2:
        {
            /* all matches */
            SB_uint16* st = (SB_uint16*) parse_state->scanner_table;
            SB_trans_uint16* tst =
                (SB_trans_uint16*) parse_state->transition_table;
            uint16 state = 0, last = state, prev = state;
            uint8 c;
            uint32 sb, so;
            c = (uint8) *s++;
            while ((
                state =
                    st[state].scanner_block[(sb = (c >> SCANNER_BLOCK_SHIFT))]
                                           [(so = c & SCANNER_BLOCK_MASK)]))
            {
                state -= 1;
                if (prev && parse_state->accepts_diff)
                {
                    shift_diff =
                        parse_state
                            ->accepts_diff[tst[prev].scanner_block[sb][so]];
                    for (; *shift_diff; shift_diff++)
                    {
                        results[nresults].loc = loc;
                        results[nresults++].shift = *shift_diff;
                    }
                }
                prev = state;
                loc.s = s;
                loc.line = line;
                loc.col = col;
                if (st[state].shift)
                {
                    last = state;
                    last_loc = loc;
                }
                if (c == '\n')
                {
                    line++;
                    col = 0;
                }
                else
                    col++;
                c = (uint8) *s++;
            }
            shift = st[last].shift;
            break;
        }
        case 4:
        {
            /* all matches */
            SB_uint32* st = (SB_uint32*) parse_state->scanner_table;
            SB_trans_uint32* tst =
                (SB_trans_uint32*) parse_state->transition_table;
            uint32 state = 0, last = state, prev = state;
            uint8 c;
            uint32 sb, so;
            c = (uint8) *s++;
            while ((
                state =
                    st[state].scanner_block[(sb = (c >> SCANNER_BLOCK_SHIFT))]
                                           [(so = c & SCANNER_BLOCK_MASK)]))
            {
                state -= 1;
                if (prev && parse_state->accepts_diff)
                {
                    shift_diff =
                        parse_state
                            ->accepts_diff[tst[prev].scanner_block[sb][so]];
                    for (; *shift_diff; shift_diff++)
                    {
                        results[nresults].loc = loc;
                        results[nresults++].shift = *shift_diff;
                    }
                }
                prev = state;
                loc.s = s;
                loc.line = line;
                loc.col = col;
                if (st[state].shift)
                {
                    last = state;
                    last_loc = loc;
                }
                if (c == '\n')
                {
                    line++;
                    col = 0;
                }
                else
                    col++;
                c = (uint8) *s++;
            }
            shift = st[last].shift;
            break;
        }
    }
    if (shift)
    {
        for (; *shift; shift++)
        {
            results[nresults].loc = last_loc;
            results[nresults++].shift = *shift;
        }
    }
    if (nresults)
    {
        int longest = 0;
        char* end = results[nresults - 1].loc.s;
        if (parse_state->scan_kind == D_SCAN_LONGEST)
            longest = 1;
        if (parse_state->scan_kind == D_SCAN_MIXED)
        {
            for (i = nresults - 1; i >= 0; i--)
            {
                if (results[i].loc.s < end)
                    break;
                if (results[i].shift->shift_kind == D_SCAN_LONGEST)
                    longest = 1;
            }
        }
        if (longest)
        {
            /* keep only 'longest' */
            i = 0;
            for (j = 0; j < nresults; j++)
            {
                if (results[j].loc.s == end ||
                    results[j].shift->shift_kind == D_SCAN_TRAILING)
                {
                    if (i != j)
                        results[i] = results[j];
                    i++;
                }
            }
            nresults = i;
        }
        else if (parse_state->scan_kind == D_SCAN_MIXED)
        {
            /* only keep non-longest */
            for (j = i; j >= 0; j--)
                if (results[j].shift->shift_kind != D_SCAN_LONGEST)
                {
                    if (i != j)
                        results[i] = results[j];
                    i--;
                }
            nresults = nresults - i - 1;
            if (i != -1)
                memmove(&results[0],
                        &results[i + 1],
                        nresults * sizeof(results[0]));
        }
    }
    return nresults;
}
