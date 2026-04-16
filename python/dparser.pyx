# cython: language_level=3
from libc.string cimport strncpy
cimport cython
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

# These macro definitions MUST appear before any C headers are included so that
# dparse.h (pulled in transitively by d.h) sees D_ParseNode_User = user_pyobjects
# and allocates the correct inline user struct inside D_ParseNode.
cdef extern from *:
    """
    typedef struct user_pyobjects {
      PyObject *t;
      PyObject *s;
      int inced_global_state;
    } user_pyobjects;
    #define D_ParseNode_User user_pyobjects
    #define D_ParseNode_Globals PyObject
    """
    cdef D_ParseNode* D_PN(void* new_ps, int pn_offset)
    ctypedef struct user_pyobjects:
        PyObject *t
        PyObject *s
        int inced_global_state

# d.h is a kitchen-sink include for all dparser headers.  It must come AFTER
# the macro block above so that dparse.h sees our D_ParseNode_User define.
cdef extern from "../d.h":
    pass

cdef extern from "../util.h":
    int d_debug_level

d_debug_level = 0

cdef extern from "../dparse_tables.h":
    ctypedef struct d_loc_t:
        char *s
        char *pathname
        char *ws
        int col
        int line

    ctypedef struct D_Symbol:
        int kind
        char *name
        int start_symbol

    ctypedef void (*D_WhiteSpaceFn)(D_Parser *p, d_loc_t *loc, void **p_globals)
    ctypedef int (*D_ReductionCode)(void *new_ps, void **children, int n_children, int pn_offset, D_Parser *parser)

    enum:
        D_SYMBOL_NTERM = 1
        D_SYMBOL_INTERNAL = 2
        D_SYMBOL_EBNF = 3
        D_SYMBOL_STRING = 4
        D_SYMBOL_REGEX = 5
        D_SYMBOL_CODE = 6
        D_SYMBOL_TOKEN = 7

cdef extern from "../dparse.h":
    ctypedef struct D_ParserTables:
        unsigned int nsymbols
        D_Symbol *symbols

    ctypedef struct D_Reduction:
        int nelements
        int symbol
        void *shifts
        int l
        int action_index

    # PNode is an internal dparser structure (defined in parse.h, available
    # after d.h).  We access it to retrieve action_index from the reduction.
    ctypedef struct PNode:
        unsigned int hash
        int assoc
        int priority
        int op_assoc
        int op_priority
        unsigned int refcount
        unsigned int height
        unsigned char evaluated
        unsigned char error_recovery
        D_Reduction *reduction

    # With D_ParseNode_User = user_pyobjects the C struct has an inline
    # user_pyobjects at the end; the Cython declaration must match.
    ctypedef struct D_ParseNode:
        int symbol
        d_loc_t start_loc
        char *end
        char *end_skip
        void *scope
        user_pyobjects user

    ctypedef void (*D_SyntaxErrorFn)(D_Parser *)
    ctypedef D_ParseNode* (*D_AmbiguityFn)(D_Parser *, int n, D_ParseNode **v)
    ctypedef void (*D_FreeNodeFn)(D_ParseNode *d)

    # D_Parser.initial_globals is typed D_ParseNode_Globals* = PyObject* in C;
    # we keep void* here and cast explicitly to avoid Cython PyObject* handling.
    ctypedef struct D_Parser:
        void *initial_globals
        D_WhiteSpaceFn initial_white_space_fn
        D_SyntaxErrorFn syntax_error_fn
        D_AmbiguityFn ambiguity_fn
        D_FreeNodeFn free_node_fn
        d_loc_t loc
        int start_state
        int sizeof_user_parse_node
        int save_parse_tree
        int dont_compare_stacks
        int dont_fixup_internal_productions
        int fixup_EBNF_productions
        int dont_merge_epsilon_trees
        int dont_use_height_for_disambiguation
        int dont_use_greediness_for_disambiguation
        int dont_use_deep_priorities_for_disambiguation
        int commit_actions_interval
        int error_recovery
        int partial_parses
        int syntax_errors

    D_Parser *new_D_Parser(D_ParserTables *t, int sizeof_ParseNode_User)
    void free_D_Parser(D_Parser *p)
    D_ParseNode *dparse(D_Parser *p, char *buf, int buf_len)
    void free_D_ParseNode(D_Parser *p, D_ParseNode *pn)
    void free_D_ParseTreeBelow(D_Parser *p, D_ParseNode *pn)
    int d_get_number_of_children(D_ParseNode *pn)
    D_ParseNode *d_get_child(D_ParseNode *pn, int child)
    char *d_ws_after(D_Parser *p, D_ParseNode *pn)

cdef extern from "../gram.h":
    cdef struct Grammar:
        int set_op_priority_from_rule
        int right_recursive_BNF
        int states_for_whitespace
        int states_for_all_nterms
        int tokenizer
        int longest_match
        char grammar_ident[256]
        int scanner_blocks
        int scanner_block_size
        int write_line_directives
        int write_header
        int token_type
        char write_extension[256]
        char *write_pathname
        char *actions_write_pathname
    Grammar *new_D_Grammar(char *pathname)
    void free_D_Grammar(Grammar *g)

cdef extern from "../mkdparse.h":
    void mkdparse_from_string(Grammar *g, char *str)

cdef extern from "../write_tables.h":
    int write_binary_tables(Grammar *g)

cdef extern from "../read_binary.h":
    cdef struct BinaryTables:
        D_ParserTables *parser_tables_gram
        char *tables
    BinaryTables *read_binary_tables(char *file_name, D_ReductionCode spec_code, D_ReductionCode final_code)
    void free_BinaryTables(BinaryTables *binary_tables)

import hashlib
import sys
import os
import types

class ParsingException(Exception):
    pass

class AmbiguityException(Exception):
    pass

class SyntaxErr(Exception):
    pass

class NoActionsFound(Exception):
    pass

class Reject:
    pass

cdef public void d_version(char *v) noexcept with gil:
    if v != NULL:
        v[0] = 0

# ---------------------------------------------------------------------------
# Python-visible wrappers around C structs
# ---------------------------------------------------------------------------

cdef class DLoc:
    cdef d_loc_t *ptr
    cdef bytes buf_bytes
    cdef long buf_start_addr

    def __init__(self):
        pass

    @property
    def s(self):
        return (<long>self.ptr.s) - self.buf_start_addr

    @s.setter
    def s(self, long val):
        self.ptr.s = <char*>(self.buf_start_addr + val)

    @property
    def line(self):
        return self.ptr.line

    @property
    def col(self):
        return self.ptr.col

    @property
    def buf(self):
        return self.buf_bytes


cdef class DParseNode:
    cdef D_ParseNode *ptr
    cdef bytes buf_bytes
    cdef long buf_start_addr

    def __init__(self):
        pass

    @property
    def symbol(self):
        return self.ptr.symbol

    @property
    def start_loc(self):
        cdef DLoc loc = DLoc()
        loc.ptr = &self.ptr.start_loc
        loc.buf_bytes = self.buf_bytes
        loc.buf_start_addr = self.buf_start_addr
        return loc

    @property
    def user(self):
        class _User:
            pass
        u = _User()
        u.t = <object>self.ptr.user.t if self.ptr.user.t != NULL else None
        u.s = <object>self.ptr.user.s if self.ptr.user.s != NULL else None
        return u

    def __str__(self):
        cdef long st = (<long>self.ptr.start_loc.s) - self.buf_start_addr
        cdef long ed = (<long>self.ptr.end) - self.buf_start_addr
        return self.buf_bytes[st:ed].decode('utf-8')

    def __repr__(self):
        return self.__str__()

    def __len__(self):
        cdef long st = (<long>self.ptr.start_loc.s) - self.buf_start_addr
        cdef long ed = (<long>self.ptr.end) - self.buf_start_addr
        return max(0, ed - st)

    @property
    def end(self):
        return (<long>self.ptr.end) - self.buf_start_addr

    @property
    def end_skip(self):
        return (<long>self.ptr.end_skip) - self.buf_start_addr

    @property
    def buf(self):
        return self.buf_bytes

# ---------------------------------------------------------------------------
# C-level callbacks
# ---------------------------------------------------------------------------

cdef void my_free_node_fn(D_ParseNode *d) noexcept with gil:
    if d.user.t != NULL:
        Py_DECREF(<object>d.user.t)
        d.user.t = NULL
    if d.user.s != NULL:
        Py_DECREF(<object>d.user.s)
        d.user.s = NULL


cdef void my_syntax_error_fn(D_Parser *dp) noexcept with gil:
    cdef DLoc loc
    if dp.initial_globals == NULL:
        return
    p = <object>dp.initial_globals
    if p.syntax_error_fn:
        loc = DLoc()
        loc.ptr = &dp.loc
        loc.buf_bytes = p.buf
        loc.buf_start_addr = <long><char*>p.buf
        p.syntax_error_fn(loc)


cdef void my_initial_white_space_fn(D_Parser *dp, d_loc_t *loc, void **p_globals) noexcept with gil:
    cdef DLoc l
    if dp.initial_globals == NULL:
        return
    p = <object>dp.initial_globals
    if p.initial_skip_space_fn:
        l = DLoc()
        l.ptr = loc
        l.buf_bytes = p.buf
        l.buf_start_addr = <long><char*>p.buf
        p.initial_skip_space_fn(l)


cdef D_ParseNode* my_ambiguity_fn(D_Parser *dp, int n, D_ParseNode **v) noexcept with gil:
    cdef list nodes = []
    cdef int i
    cdef DParseNode node
    if dp.initial_globals == NULL:
        return v[0]
    p = <object>dp.initial_globals
    if not p.ambiguity_fn:
        return v[0]
    for i in range(n):
        node = DParseNode()
        node.ptr = v[i]
        node.buf_bytes = p.buf
        node.buf_start_addr = <long><char*>p.buf
        nodes.append(node)
    try:
        res = p.ambiguity_fn(nodes)
        for i in range(n):
            if nodes[i] is res:
                return v[i]
    except Exception:
        return v[0]
    return v[0]


cdef int has_deeper_nodes(D_Parser *parser, D_ParseNode *d) noexcept with gil:
    if d == NULL:
        return 0
    if parser.initial_globals == NULL:
        return 0
    p = <object>parser.initial_globals
    cdef long tables_ptr = p.tables.getTables()
    if tables_ptr == 0:
        return 0
    cdef BinaryTables* bt = <BinaryTables*>tables_ptr
    if bt == NULL or bt.parser_tables_gram == NULL or bt.parser_tables_gram.symbols == NULL:
        return 0
    cdef int kind = bt.parser_tables_gram.symbols[d.symbol].kind
    return kind == D_SYMBOL_INTERNAL or kind == D_SYMBOL_EBNF


cdef list pylist_children(D_Parser *parser, D_ParseNode *d, int string) with gil:
    cdef int nc = d_get_number_of_children(d)
    cdef list lst = []
    cdef D_ParseNode *child
    for i in range(nc):
        child = d_get_child(d, i)
        lst.append(make_pyobject_from_node(parser, child, string))
    return lst


cdef object make_pyobject_from_node(D_Parser *parser, D_ParseNode *d, int string) with gil:
    if d == NULL:
        return None
    cdef object user_obj = None
    cdef char *end_ptr = NULL
    if string:
        if d.user.s != NULL:
            user_obj = <object>d.user.s
    else:
        if d.user.t != NULL:
            user_obj = <object>d.user.t

    if user_obj is None:
        if has_deeper_nodes(parser, d):
            user_obj = pylist_children(parser, d, string)
        else:
            if parser.initial_globals == NULL:
                return None
            p = <object>parser.initial_globals
            if string:
                end_ptr = d_ws_after(parser, d)
            else:
                end_ptr = d.end
            st = (<long>d.start_loc.s) - <long><char*>p.buf
            ed = (<long>end_ptr) - <long><char*>p.buf
            user_obj = p.buf[st:ed].decode('utf-8')

    return user_obj


cdef int my_action(void *new_ps, void **children, int n_children, int pn_offset,
                   D_Parser *parser, int speculative) noexcept with gil:
    cdef D_ParseNode* dd = D_PN(new_ps, pn_offset)
    if dd == NULL:
        return -1
    cdef PNode* pnode = <PNode*>new_ps
    cdef long action_index = pnode.reduction.action_index if pnode != NULL and pnode.reduction != NULL else -1
    cdef object py_res = None
    cdef list children_list = None
    cdef list string_list = None
    cdef object action_fn
    cdef int takes_speculative
    cdef list args
    cdef list nodes_arr
    cdef DParseNode n
    cdef tuple action_tuple = None

    if parser.initial_globals == NULL:
        return 0  # sub-parser (e.g. whitespace): no Python context, just succeed
    p = <object>parser.initial_globals

    if action_index != -1 and action_index < len(p.actions):
        action_tuple = p.actions[action_index]
        if action_tuple is not None:
            takes_speculative = action_tuple[2]
            # takes_speculative == -1 means "final actions only"; skip speculative pass
            if takes_speculative == -1 and speculative:
                return 0

    string_list = pylist_children(parser, dd, 1)

    # Action exists but does not want to run speculatively: store a sentinel
    if action_index != -1 and action_tuple is not None and takes_speculative == 0 and speculative:
        if dd.user.t != NULL:
            Py_DECREF(<object>dd.user.t)
        if dd.user.s != NULL:
            Py_DECREF(<object>dd.user.s)
        Py_INCREF(None)
        dd.user.t = <PyObject*>None
        dd.user.s = NULL
        return 0

    children_list = pylist_children(parser, dd, 0)
    if children_list is None:
        return -1

    if action_index != -1 and action_tuple is not None:
        action_fn = action_tuple[0]
        arg_types = action_tuple[1]

        args = [children_list]
        for arg_t in arg_types[1:]:
            if arg_t == 1:        # spec
                args.append(speculative)
            elif arg_t == 2:      # g (globals placeholder)
                args.append(None)
            elif arg_t == 3:      # s (string children)
                args.append(string_list)
            elif arg_t == 4:      # nodes (DParseNode list)
                nodes_arr = []
                for i in range(n_children):
                    n = DParseNode()
                    n.ptr = D_PN(children[i], pn_offset)
                    n.buf_bytes = p.buf
                    n.buf_start_addr = <long><char*>p.buf
                    nodes_arr.append(n)
                args.append(nodes_arr)
            elif arg_t == 5:      # this (current DParseNode)
                n = DParseNode()
                n.ptr = dd
                n.buf_bytes = p.buf
                n.buf_start_addr = <long><char*>p.buf
                args.append(n)
            elif arg_t == 6:      # spec_only
                args.append(speculative)
            elif arg_t == 7:      # parser
                args.append(p)
            else:
                args.append(None)

        try:
            py_res = action_fn(*args)
            if py_res is Reject or isinstance(py_res, Reject) or (
                    isinstance(py_res, type) and issubclass(py_res, Reject)):
                return -1
        except Exception:
            import traceback
            traceback.print_exc()
            return -1
    else:
        py_res = children_list

    # Store result in node user area (DECREF old values first).
    if dd.user.t != NULL:
        Py_DECREF(<object>dd.user.t)
    if dd.user.s != NULL:
        Py_DECREF(<object>dd.user.s)

    Py_INCREF(py_res)
    dd.user.t = <PyObject*>py_res

    Py_INCREF(string_list)
    dd.user.s = <PyObject*>string_list

    return 0


cdef int my_final_action(void *new_ps, void **children, int n_children,
                         int pn_offset, D_Parser *parser) noexcept with gil:
    return my_action(new_ps, children, n_children, pn_offset, parser, 0)


cdef int my_speculative_action(void *new_ps, void **children, int n_children,
                               int pn_offset, D_Parser *parser) noexcept with gil:
    return my_action(new_ps, children, n_children, pn_offset, parser, 1)

# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def my_syntax_error_func(loc):
    ee = '...'
    be = '...'
    width = 25
    mn = loc.s - width
    if mn < 0:
        mn = 0
        be = ''
    mx = loc.s + 25
    if mx > len(loc.buf):
        mx = len(loc.buf)
        ee = ''
    begin = loc.buf[mn:loc.s].decode('utf-8')
    end = loc.buf[loc.s:mx].decode('utf-8')
    raise SyntaxErr('\n\nsyntax error, line:' + str(loc.line) + '\n\n' +
                    be + begin + '[syntax error]' + end + ee + '\n')


def my_ambiguity_func(nodes):
    raise AmbiguityException("\nunresolved ambiguity.  Symbols:\n" +
                             '\n'.join([str(node.symbol) for node in nodes]))

# ---------------------------------------------------------------------------
# Tables
# ---------------------------------------------------------------------------

class Tables:
    def __init__(self):
        self.sig = hashlib.md5(u'1.31'.encode('utf-8'))
        self.tables = <long>0

    def __del__(self):
        cdef long tables_ptr = self.tables
        if tables_ptr:
            free_BinaryTables(<BinaryTables*>tables_ptr)
            self.tables = 0

    def update(self, data):
        self.sig.update(data.encode('utf-8'))

    def sig_changed(self, filename):
        md5_path = filename + '.md5'
        if os.path.exists(md5_path):
            with open(md5_path, 'rb') as fh:
                return fh.read() != self.sig.digest()
        return True

    def load_tables(self, grammar_str, filename, make_grammar_file):
        cdef Grammar *g
        cdef bytes output_file
        cdef bytes tf
        cdef BinaryTables* bt

        cdef long old_tables = self.tables
        if old_tables:
            free_BinaryTables(<BinaryTables*>old_tables)
            self.tables = 0

        if make_grammar_file:
            with open(filename, 'wb') as fh:
                fh.write(grammar_str)

        if self.sig_changed(filename):
            g = new_D_Grammar(filename.encode())
            g.set_op_priority_from_rule = 0
            g.right_recursive_BNF = 0
            g.states_for_whitespace = 1
            g.states_for_all_nterms = 1
            g.tokenizer = 0
            g.longest_match = 0
            g.scanner_block_size = 0
            g.write_line_directives = 1
            g.write_header = -1
            g.token_type = 0
            g.scanner_blocks = 4
            strncpy(g.grammar_ident, b"gram", 255)
            strncpy(g.write_extension, b"dat", 255)

            output_file = (filename + ".d_parser.dat").encode()
            g.write_pathname = output_file
            g.actions_write_pathname = b""

            mkdparse_from_string(g, grammar_str)
            write_binary_tables(g)
            free_D_Grammar(g)

            with open(filename + '.md5', 'wb') as fh:
                fh.write(self.sig.digest())

        tf = (filename + ".d_parser.dat").encode("utf-8")
        bt = read_binary_tables(tf, my_speculative_action, my_final_action)
        if bt == NULL:
            raise RuntimeError(f"failed to load binary tables from {tf.decode()}")
        self.tables = <long>bt  # store full BinaryTables*

    def getTables(self):
        return self.tables  # returns BinaryTables* as long

# ---------------------------------------------------------------------------
# ParsedStructure
# ---------------------------------------------------------------------------

class ParsedStructure:
    def __init__(self, result):
        self.string_left = ""
        self.structure = None
        self.top_node = None
        if result:
            if len(result) == 3:
                self.string_left = result[2]
            self.top_node = result[1]
            self.structure = result[0]

    def getStructure(self):
        return self.structure

    def getStringLeft(self):
        return self.string_left

# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

class Parser:
    def __init__(self, modules=None, parser_folder=None,
                 file_prefix="d_parser_mach_gen", make_grammar_file=False):
        self.tables = Tables()
        self.actions = []

        if not modules:
            try:
                caller_frame = sys._getframe(1)
                dicts = [caller_frame.f_globals]
            except Exception:
                import __main__
                dicts = [__main__.__dict__]
        elif isinstance(modules, list):
            dicts = [module.__dict__ for module in modules]
        elif isinstance(modules, dict):
            dicts = [modules]
        else:
            dicts = [modules.__dict__]

        functions = []
        for dictionary in dicts:
            f = [val for name, val in dictionary.items()
                 if isinstance(val, types.FunctionType) and name.startswith("d_")]
            f = sorted(f, key=lambda x: (x.__code__.co_filename, x.__code__.co_firstlineno))
            functions.extend(f)

        if not functions:
            raise NoActionsFound("\nno actions found.  Action names must start with 'd_'")

        if not parser_folder:
            parser_folder = os.path.dirname(sys.argv[0])
            if not parser_folder:
                parser_folder = os.getcwd()
            parser_folder = parser_folder.replace('\\', '/')

        self.filename = os.path.join(parser_folder, file_prefix + ".g")

        grammar_str = []
        self.takes_strings = 0
        self.takes_globals = 0
        for f in functions:
            if not f.__doc__:
                raise RuntimeError("\naction missing doc string:\n\t" + f.__name__)
            
            doc = f.__doc__
            self.tables.update(doc)
            
            # Robust split by '|' that respects quoted strings and regexes
            doc_rules = []
            start = 0
            i = 0
            while i < len(doc):
                c = doc[i]
                if c == '"':  # regex
                    i += 1
                    while i < len(doc) and doc[i] != '"':
                        if doc[i] == '\\': i += 1
                        i += 1
                elif c == "'":  # string
                    i += 1
                    while i < len(doc) and doc[i] != "'":
                        if doc[i] == '\\': i += 1
                        i += 1
                elif c == '|':
                    doc_rules.append(doc[start:i])
                    start = i + 1
                i += 1
            doc_rules.append(doc[start:])

            grammar_str.append(doc_rules[0].strip())
            grammar_str.append(" ${action}")
            for i in range(1, len(doc_rules)):
                grammar_str.append(" | ")
                grammar_str.append(doc_rules[i].strip())
                grammar_str.append(" ${action}")
            grammar_str.append(";\n")

            if f.__code__.co_argcount == 0:
                raise RuntimeError("\naction " + f.__name__ +
                                   " must take at least one argument\n")
            speculative = 0
            arg_types = [0]
            for i in range(1, f.__code__.co_argcount):
                var = f.__code__.co_varnames[i]
                if var == 'spec':
                    arg_types.append(1)
                    speculative = 1
                elif var == 'g':
                    arg_types.append(2)
                    self.takes_globals = 1
                elif var == 's':
                    arg_types.append(3)
                    self.takes_strings = 1
                elif var == 'nodes':
                    arg_types.append(4)
                elif var == 'this':
                    arg_types.append(5)
                elif var == 'spec_only':
                    arg_types.append(6)
                    speculative = -1
                elif var == 'parser':
                    arg_types.append(7)
                else:
                    raise RuntimeError("\nunknown action argument " + var)
            if not speculative:
                speculative = -1
            for i in range(len(doc_rules)):
                self.actions.append((f, arg_types, speculative))

        grammar_str = ''.join(grammar_str).encode()
        self.tables.load_tables(grammar_str, self.filename, make_grammar_file)

    def parse(self, buf, buf_offset=0, initial_skip_space_fn=None,
              syntax_error_fn=None, ambiguity_fn=None, make_token=None,
              dont_fixup_internal_productions=False, fixup_EBNF_productions=False,
              dont_merge_epsilon_trees=False, commit_actions_interval=100,
              error_recovery=False, print_debug_info=0, partial_parses=False,
              dont_compare_stacks=False, dont_use_greediness_for_disambiguation=False,
              dont_use_height_for_disambiguation=False, start_symbol=''):
        cdef BinaryTables* bt
        cdef D_Parser* dp
        cdef D_ParseNode* pn
        cdef bytes buf_bytes
        cdef char *buf_ptr
        cdef long tables_ptr
        cdef long st, ed

        self.buf = buf.encode('utf-8') if isinstance(buf, str) else buf
        self.initial_skip_space_fn = initial_skip_space_fn
        self.syntax_error_fn = syntax_error_fn
        self.ambiguity_fn = ambiguity_fn

        tables_ptr = self.tables.getTables()
        if tables_ptr == 0:
            raise RuntimeError("binary tables are missing")
        bt = <BinaryTables*>tables_ptr
        if bt == NULL or bt.parser_tables_gram == NULL:
            raise RuntimeError("parser tables are missing")

        dp = new_D_Parser(bt.parser_tables_gram, sizeof(user_pyobjects))
        # Store self so all C callbacks can retrieve the Parser object.
        # self is kept alive by the call stack for the duration of dparse().
        dp.initial_globals = <void*><PyObject*>self

        if syntax_error_fn is not None:
            dp.syntax_error_fn = my_syntax_error_fn
        if initial_skip_space_fn is not None:
            dp.initial_white_space_fn = my_initial_white_space_fn
        if ambiguity_fn is not None:
            dp.ambiguity_fn = my_ambiguity_fn

        dp.free_node_fn = my_free_node_fn
        dp.partial_parses = 1 if partial_parses else 0
        dp.error_recovery = 1 if error_recovery else 0
        dp.dont_fixup_internal_productions = 1 if dont_fixup_internal_productions else 0
        dp.fixup_EBNF_productions = 1 if fixup_EBNF_productions else 0
        dp.dont_merge_epsilon_trees = 1 if dont_merge_epsilon_trees else 0
        dp.commit_actions_interval = commit_actions_interval
        dp.dont_compare_stacks = 1 if dont_compare_stacks else 0
        dp.dont_use_greediness_for_disambiguation = 1 if dont_use_greediness_for_disambiguation else 0
        dp.dont_use_height_for_disambiguation = 1 if dont_use_height_for_disambiguation else 0
        dp.save_parse_tree = 1

        buf_bytes = self.buf
        buf_ptr = <char*>buf_bytes

        pn = dparse(dp, buf_ptr + <int>buf_offset, len(self.buf) - buf_offset)

        if pn == NULL:
            free_D_Parser(dp)
            raise SyntaxErr("syntax error during parse")

        # Extract results while the tree is still alive.
        # Cython INCREFs when assigning <object> to a Python variable, so
        # result/s_list_res each own one ref.  free_D_ParseNode will then
        # DECREF via my_free_node_fn, balancing my_action's Py_INCREF.
        result = <object>pn.user.t if pn.user.t != NULL else None
        if pn.user.s != NULL:
            s_list_res = <object>pn.user.s
        else:
            st = (<long>pn.start_loc.s) - <long>buf_ptr
            ed = (<long>pn.end) - <long>buf_ptr
            s_list_res = buf_bytes[st:ed].decode('utf-8')

        free_D_ParseTreeBelow(dp, pn)
        free_D_ParseNode(dp, pn)
        free_D_Parser(dp)

        return ParsedStructure([result, None, s_list_res])
