# Copyright (c) 2003, 2004 Brian Sabbey
# contributions by Milosz Krajewski
# contributions by John Plevyak

import sys
import types
import os
import hashlib
import dparser_swigc


class user_pyobjectsPtr:
    def __init__(self, this):
        self.this = this

    def __setattr__(self, name, value):
        if name == "t":
            self.this.t = value
            return
        self.__dict__[name] = value

    def __getattr__(self, name):
        if name == "t":
            return self.this.t
        raise AttributeError(name)

    def __repr__(self):
        return "<C user_pyobjects instance>"


class d_loc_tPtr:
    def __init__(self, this, d_parser):
        self.this = this
        self.d_parser = d_parser

    def __setattr__(self, name, value):
        if name == "s":
            dparser_swigc.my_d_loc_t_s_set(self.this, self.d_parser, value)
        elif name in ["pathname", "previous_col", "col", "line", "ws"]:
            self.this.__setattr__(name, value)
        else:
            self.__dict__[name] = value

    def __getattr__(self, name):
        if name == "s":
            return dparser_swigc.my_d_loc_t_s_get(self.this, self.d_parser)
        elif name in ["pathname", "previous_col", "col", "line", "ws"]:
            return self.this.__getattribute__(name)
        raise AttributeError(name)

    def __repr__(self):
        return "<C d_loc_t instance>"


class d_loc_t(d_loc_tPtr):
    def __init__(self, this, d_parser, buf):
        d_loc_tPtr.__init__(self, this, d_parser)
        self.buf = buf


class D_ParseNodePtr:
    def __init__(self, this):
        self.this = this

    def __setattr__(self, name, value):
        if name == "end_skip":
            dparser_swigc.my_D_ParseNode_end_skip_set(self.this, self.d_parser,
                                                      value)
        elif name == "end":
            dparser_swigc.my_D_ParseNode_end_set(self.this, self.d_parser,
                                                 value)
        elif name in ["start_loc", "user"]:
            self.this.__setattr__(name, value)
        else:
            self.__dict__[name] = value

    def __getattr__(self, name):
        if name == "symbol":
            return dparser_swigc.my_D_ParseNode_symbol_get(
                    self.this, self.d_parser)
        elif name == "end":
            return dparser_swigc.my_D_ParseNode_end_get(
                    self.this, self.d_parser)
        elif name == "end_skip":
            return dparser_swigc.my_D_ParseNode_end_skip_get(
                    self.this, self.d_parser)
        elif name == "number_of_children":
            return dparser_swigc.d_get_number_of_children(self.this)
        elif name == "user":
            return user_pyobjectsPtr(self.this.user)
        elif name == "start_loc":
            val = self.__dict__.get(name)
            if not val:
                val = self.__dict__[name] = d_loc_t(
                        self.this.start_loc, self.d_parser, self.buf)
            return val
        elif name == "c":
            children = self.__dict__.get(name, None)
            if not children:
                dparser_swigc.d_get_number_of_children(self.this)
                children = []
                for i in xrange(dparser_swigc.d_get_number_off_children(
                                self.this)):
                    children.append(
                        D_ParseNode(dparser_swigc.d_get_child(self.this, i),
                                    self.d_parser, self.buf)
                    )
                self.__dict__[name] = children
            return children
        raise AttributeError(name)

    def __repr__(self):
        return "<C D_ParseNode instance>"


class D_ParseNode(D_ParseNodePtr):
    def __init__(self, this, d_parser, buf):
        D_ParseNodePtr.__init__(self, this)
        self.d_parser = d_parser
        self.buf = buf
        dparser_swigc.add_parse_tree_viewer(self.d_parser)

    def __del__(self):
        dparser_swigc.remove_parse_tree_viewer(self.d_parser)


class Reject:
    pass


class SyntaxErr(Exception):
    pass


class AmbiguityException(Exception):
    pass


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
    s = ('\n\nsyntax error, line:' + str(loc.line) + '\n\n' + be +
         begin + '[syntax error]' + end + ee + '\n')
    raise SyntaxErr(s)


def my_ambiguity_func(nodes):
    raise AmbiguityException("\nunresolved ambiguity.  Symbols:\n" +
                             '\n'.join([node.symbol for node in nodes]))


class Tables:
    def __init__(self):
        self.sig = hashlib.md5(u'1.31'.encode('utf-8'))
        self.tables = None

    def __del__(self):
        if self.tables:
            dparser_swigc.unload_parser_tables(self.tables)

    def update(self, data):
        self.sig.update(data.encode('utf-8'))

    def sig_changed(self, filename):
        filename = filename + '.md5'
        if os.path.exists(filename):
            with open(filename, 'rb') as fh:
                return fh.read() != self.sig.digest()
        return True

    def load_tables(self, grammar_str, filename, make_grammar_file):
        if make_grammar_file:
            with open(filename, 'wb') as fh:
                fh.write(grammar_str)

        if self.sig_changed(filename):
            dparser_swigc.make_tables(grammar_str, filename.encode())
            with open(filename + '.md5', 'wb') as fh:
                fh.write(self.sig.digest())

        if self.tables:
            dparser_swigc.unload_parser_tables(self.tables)
        self.tables = dparser_swigc.load_parser_tables(
                (filename + ".d_parser.dat").encode('utf-8'))

    def getTables(self):
        return self.tables


class ParsingException(Exception):
    pass


class NoActionsFound(Exception):
    pass


class Parser:
    def __init__(self, modules=None, parser_folder=None,
                 file_prefix="d_parser_mach_gen", make_grammar_file=False):
        self.tables = Tables()
        self.actions = []
        if not modules:
            try:
                raise RuntimeError
            except RuntimeError:
                traceback = sys.exc_info()[2]
                dicts = [traceback.tb_frame.f_back.f_globals]
        else:
            if isinstance(modules, list):
                dicts = [module.__dict__ for module in modules]
            elif isinstance(modules, dict):
                dicts = [modules]
            else:
                dicts = [modules.__dict__]

        functions = []
        for dictionary in dicts:
            f = [val for name, val in dictionary.items()
                 if (isinstance(val, types.FunctionType)) and
                 name[0:2] == 'd_']
            f = sorted(f, key=lambda x: (x.__code__.co_filename,
                                         x.__code__.co_firstlineno))
            functions.extend(f)
        if len(functions) == 0:
            raise "\nno actions found.  Action names must start with 'd_'"

        if parser_folder is None:
            parser_folder = os.path.dirname(sys.argv[0])
            if len(parser_folder) == 0:
                parser_folder = os.getcwd()
                parser_folder = parser_folder.replace('\\', '/')

        self.filename = os.path.join(parser_folder, file_prefix + ".g")

        grammar_str = []
        self.takes_strings = 0
        self.takes_globals = 0
        for f in functions:
            if f.__doc__:
                grammar_str.append(f.__doc__)
                self.tables.update(f.__doc__)
            else:
                raise "\naction missing doc string:\n\t" + f.__name__
            grammar_str.append(" ${action};\n")
            if f.__code__.co_argcount == 0:
                raise ("\naction " + f.__name__ +
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
                    raise ("\nunknown argument name:\n\t" + var +
                           "\nin function:\n\t" + f.__name__)
            self.actions.append((f, arg_types, speculative))
        grammar_str = ''.join(grammar_str).encode()

        self.tables.load_tables(grammar_str, self.filename, make_grammar_file)

    def parse(self, buf, buf_offset=0,
              initial_skip_space_fn=None,
              syntax_error_fn=my_syntax_error_func,
              ambiguity_fn=my_ambiguity_func,
              make_token=None,
              dont_fixup_internal_productions=False,
              fixup_EBNF_productions=False,
              dont_merge_epsilon_trees=False,
              commit_actions_interval=100,
              error_recovery=False,
              print_debug_info=False,
              partial_parses=False,
              dont_compare_stacks=False,
              dont_use_greediness_for_disambiguation=False,
              dont_use_height_for_disambiguation=False,
              start_symbol=''):

        # workaround python3/2
        t = str
        try:
            t = basestring
        except NameError:
            pass

        if not isinstance(buf, t):
            raise ParsingException(
                    "Message to parse is not a string: %r" % buf)

        # dparser works with bytes
        buf = buf.encode('utf-8')

        parser = dparser_swigc.make_parser(
            self.tables.getTables(), self, Reject, make_token, d_loc_t,
            D_ParseNode,
            self.actions, initial_skip_space_fn, syntax_error_fn, ambiguity_fn,
            dont_fixup_internal_productions, fixup_EBNF_productions,
            dont_merge_epsilon_trees, commit_actions_interval, error_recovery,
            print_debug_info, partial_parses, dont_compare_stacks,
            dont_use_greediness_for_disambiguation,
            dont_use_height_for_disambiguation,
            start_symbol.encode('utf-8'), self.takes_strings, self.takes_globals
        )
        result = dparser_swigc.run_parser(parser, buf, buf_offset)
        return ParsedStructure(result)


class ParsedStructure:
    def __init__(self, result):
        self.string_left = ""
        self.structure = None
        self.top_node = None
        if result:
            if len(result) == 3:
                self.string_left = result[2]
            node = result[1]
            # D_ParseNode(node.this, node.d_parser, node.buf)
            self.top_node = node
            self.structure = result[0]

    def getStructure(self):
        return self.structure

    def getStringLeft(self):
        return self.string_left
