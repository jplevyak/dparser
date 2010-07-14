import dparser
from time import time
from gc import get_objects, collect
from random import random

def d_S(t, s, spec):
  '''S : a b c'''
  
def d_a(t, s, g, spec):
  '''a : 'a' | b '''
  s = 'b1'
  g[0] = ['b2']


def d_b(t, g, s, spec):
  '''b : d | 'b' | 'B' '''
  g[0] = ['b3']
  if random() < 0.5:
    global raised
    raised = 1
    raise 'b4'
  return ['b5']

def d_c(t, nodes, this, parser, s, spec):
  '''c : 'c' '''

def d_d(t, s, spec):
  '''d : 'd' '''
  
p = dparser.Parser()

caught = 0  
for mx in [1,10,100,1000]:
  t = time()
  i = 0
  bc = len(get_objects())
  while i < mx:
    try:
      raised = 0
      f = p.parse('a d c', print_debug_info=0)
    except:
      raised = 0
    if raised:
      print 'fail'
    i += 1
  ac = len(get_objects())
  x = time()
'''
  print """Created Objects per Iteration: --> %s <--
""" % ((ac-bc)/i)
'''
if ac-bc !=0:
  print 'fail ac-bc'
