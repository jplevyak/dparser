a = f(x for x in y)
b = next(i for i, (a, n) in enumerate(s) if a is attr and n is node)
c = f(x async for x in y)
d = f(x for x in y)(z for z in w)
e = f(x for x in y if a if b)
g = f((x for x in y), 1)
h = sum(x * x for x in range(10)
        if x % 2)

@f(x for x in y)
def k(): pass
