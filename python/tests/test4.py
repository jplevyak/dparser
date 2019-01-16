import dparser


def d_S(t):
    "S: a | b"
    del t
    return 'S'


def d_a(t):
    "a : x1 x1 'y'"
    del t


def d_b(t):
    "b : x2 x2 'y'"
    del t


def d_x1(t, spec):
    "x1 : 'x'"
    del t, spec


def d_x2(t, spec):
    "x2 : 'x'"
    del t
    if spec:
        return dparser.Reject


def syntax_error(t):
    del t
    print('fail')


parser = dparser.Parser()
parser.parse('xxy', syntax_error_fn=syntax_error).getStructure()
