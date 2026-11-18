a = b = 1
a, *b, (c, [d, *e]) = f
a[1:2], b.c = 1, 2
(a.b), [c[0]] = x
(a) = 1
((a), b) = 1
(*a,) = x
() = x
[] = x
f(a).b[1:2] = 3
x = *a, b
x = y = *z, w
x[0] += 1
x.y **= 2
(a) += 1
x += *a, b
del a, (b, c), [d.e], f[0]
del (a,)
del ()
for x.y, *z in w: pass
for (a, b) in c: pass
for x in *a, b: pass
[(a, b) for a, b in c]
with a as (b, c): pass
match = 1
match.x = 2
match[0] = 3
