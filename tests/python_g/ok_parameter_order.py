def a(x, y=1, /, z=2, *args, k, m=3, **kw): pass
def b(x=1, /, y=2): pass
def c(x, /, y, z=1): pass
def d(*, k): pass
def e(**kw,): pass
def g(*args: *Ts): pass
f1 = lambda x, y=1, /, z=2, *a, k, m=3, **kw: x
f2 = lambda *, k: k
f3 = lambda **kw: kw
