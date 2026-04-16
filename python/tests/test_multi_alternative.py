import sys
import pytest
from dparser import Parser

def d_add(t):
    '''add : add '+' mul
           | mul'''
    if len(t) == 1:
        return t[0]
    return t[0] + t[2]

def d_mul(t):
    '''mul : mul '*' exp
           | exp'''
    if len(t) == 1:
        return t[0]
    return t[0] * t[2]

def d_exp(t):
    '''exp : number
           | '(' add ')' '''
    if len(t) == 1:
        return int(t[0])
    return t[1]

def d_number(t):
    '''number : "[0-9]+"'''
    return t[0]

def d_whitespace(t):
    "whitespace : ( ' ' | '\\t' )*"
    pass

@pytest.fixture
def parser(tmp_path):
    return Parser(
        modules=sys.modules[__name__],
        parser_folder=str(tmp_path),
        make_grammar_file=True
    )

def test_multi_alternative_arithmetic(parser):
    # Test cases that exercise both alternatives of add and mul
    
    # Simple number (mul -> exp -> number)
    assert parser.parse('123').getStructure() == 123
    
    # Simple addition (add -> add + mul)
    assert parser.parse('1+2').getStructure() == 3
    
    # Simple multiplication (add -> mul -> mul * exp)
    assert parser.parse('2*3').getStructure() == 6
    
    # Mixed (precedence)
    assert parser.parse('1+2*3').getStructure() == 7
    assert parser.parse('1*2+3').getStructure() == 5
    
    # Parentheses
    assert parser.parse('(1+2)*3').getStructure() == 9
    
    # Complex
    assert parser.parse('1 + 2 * (3 + 4 + 5)').getStructure() == 25
