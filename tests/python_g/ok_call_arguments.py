f(a, *b, c, d=1, *e, f=2, **g, h=3, **i)
f(*a, b)
f(a=1, *b, c=2)
f(**a, b=1)
class C(A, metaclass=M, **kw): pass
