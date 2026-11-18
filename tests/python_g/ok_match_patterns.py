match a, b:
    case 1, 2: pass
match *a, b:
    case _: pass
match x:
    case -1 | 1+2j | -1.5-3j | 'a' 'b' | b'x' b'y': pass
    case [a, *rest, _] | [*_]: pass
    case {**rest}: pass
    case {'a': 1, None: _, 'x' 'y': _, a.b: _, **rest,}: pass
    case C(a, b=1,) | C() | a.b.c(x=[1, *_]) | C(_, [*_]): pass
    case (a as b) | c: pass
    case (): pass
    case a.b: pass
    case 1, *_ , : pass
    case [1, 2] as y if y: pass
    case (1 | 2) as z if (w := z): pass
    case True | False | None: pass
    case a: pass
