def f():
    return *a, b
def g():
    yield *a, b
    x = yield *a, b
    return (yield)
