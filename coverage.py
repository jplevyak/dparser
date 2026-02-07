
# Python Grammar Coverage Test

# 1. Literals
def literals():
    # Numbers
    x = 1
    y = 2.5
    z = 3j
    b = 0b1010
    o = 0o755
    h = 0xFF
    large = 1_000_000
    
    # Strings
    s1 = "hello"
    s2 = 'world'
    s3 = """multi
    line"""
    s4 = 'implicit' " concatenation"
    b1 = b"bytes"
    r1 = r"raw\n"
    f1 = f"formatted {x}"
    
    # Collections
    l = [1, 2, 3]
    t = (1, 2, 3)
    t1 = (1,)
    s = {1, 2, 3}
    d = {'a': 1, 'b': 2}
    
    # Constants
    n = None
    t = True
    f = False
    e = ...

# 2. Operations
def operations(a, b):
    # Arithmetic
    res = a + b - a * b / a // b % a ** b @ a
    
    # Bitwise
    res = a & b | a ^ b << 1 >> 1 ~a
    
    # Comparison
    if a < b <= a > b >= a == b != a is b is not a in l and not b:
        pass
    
    # Boolean
    x = True or False and not True

# 3. Statements
def statements():
    # Simple statements
    pass
    x = 1
    x += 1
    del x
    global g
    nonlocal n
    assert True, "Error"
    
    # Control Flow
    if True:
        pass
    elif False:
        pass
    else:
        pass
        
    while True:
        break
        continue
    else:
        pass
        
    for i in range(10):
        pass
    else:
        pass

# 4. Functions and Classes
@decorator
def my_func(a, b: int = 1, *args, c=2, **kwargs) -> None:
    """Docstring"""
    yield 1
    return

async def my_async():
    await my_func()

class MyClass(Base):
    x: int = 1
    
    def __init__(self):
        self.y = 2
        
    @property
    def prop(self):
        return self.x

# 5. Advanced Features
def advanced():
    # List comprehension
    sq = [x**2 for x in range(10) if x % 2 == 0]
    
    # Dict comprehension
    sq_map = {x: x**2 for x in range(10)}
    
    # Generator expression
    g = (x for x in range(10))
    
    # Set comprehension
    s = {x for x in range(10)}
    
    # Lambda
    f = lambda x: x + 1
    
    # Try/Except
    try:
        1 / 0
    except ZeroDivisionError as e:
        pass
    except (ValueError, TypeError):
        pass
    else:
        pass
    finally:
        pass
        
    # With
    with open('file') as f, open('other') as g:
        pass
        
    # Match (Python 3.10+)
    match x:
        case 1:
            pass
        case [a, b]:
            pass
        case {'k': v}:
            pass
        case _:
            pass

    # Walrus
    if (n := len(l)) > 10:
        pass

# 6. More Features
def imports():
    import os
    import sys as s
    from math import sin, cos as c
    from . import local
    from ... import deep
    from .sub import *

def type_aliases():
    type MyInt = int
    type List[T] = list[T]

def extended_unpacking():
    l = [1, 2, 3]
    a, *b, c = l
    *d, = l
    d = {**{'a': 1}, **{'b': 2}}
    s = {*{1, 2}, *{3, 4}}

async def async_features():
    async for x in range(10):
        pass
    
    async with open('file') as f:
        pass

def generators():
    yield from range(10)

@decorator
class AdvancedClass(Base, metaclass=type):
    pass

def raising():
    raise ValueError from None

if __name__ == "__main__":
    literals()
    operations(1, 2)
    statements()
    # imports() # Skip runtime execution of imports to avoid errors
    # type_aliases() # Python 3.12+

