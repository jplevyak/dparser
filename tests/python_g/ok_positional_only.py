def a(x, /): pass
def b(x, /,): pass
def c(x, y=1, /, z=2, *args, k, **kw): pass
def d(cls=None, /, *, init=True): pass
def e(self, flags: int, /) -> memoryview: pass
def g(x, /, *, y): pass
h = lambda x, /: x
i = lambda x, y=1, /, z=2, *a, k, **kw: x
j = lambda *, k: k
k = lambda: 0
def m(self, *descendants: StrPath, **kwargs: Any) -> "T": pass
def n(*args: *Ts): pass
