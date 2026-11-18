with (a as b): pass
with (a as b,): pass
with (a, b as c): pass
with (a as b, c as d): pass
with (yield) as x: pass
with (a): pass
with (a, b): pass
with (): pass
async def f():
    async with (a as b, c): pass
