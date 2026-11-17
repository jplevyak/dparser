"""Attributes after parsing: synthesized and inherited attributes over a
tree, evaluated on demand, cached, and checked for cycles.

Works on the tree from ``parser.parse(text, keep_tree=True).getTree()``, or
on any tree whose nodes have a list of children::

    from dparser_attrs import syn, inh, AttrTree, NO_EQUATION

    @inh
    def env(node, child):
        if child < 0:                      # the root's own value
            return {}
        if node.name != 'block':
            return NO_EQUATION             # copy down from the parent
        return {**env(node), **declarations(node)}

    @syn
    def type(node):
        if node.name == 'number':
            return 'int'
        ...

    tree = AttrTree(parse_tree)
    print(type(tree.root))

An equation receives AttrNodes, which have ``parent``, ``index`` (within the
parent, -1 for the root) and ``children``, and pass any other attribute
through to the underlying node (``name``, ``text``, ...).  Calling an
attribute on an AttrNode gives its value.

A synthesized equation, ``f(node)``, computes the value at ``node``.  An
inherited equation, ``f(parent, child_index)``, computes the value
``parent`` gives its child number ``child_index``; at the root it is called
as ``f(root, -1)``.  Returning ``NO_EQUATION`` makes a synthesized value
undefined (``None``) and copies an inherited value down from the nearest
ancestor that has an equation.  A value that depends on itself raises
``AttributeCycle``.
"""

__all__ = ['Attribute', 'AttrTree', 'AttrNode', 'AttributeCycle', 'NO_EQUATION', 'syn', 'inh']


class _NoEquation:
    def __repr__(self):
        return 'NO_EQUATION'


NO_EQUATION = _NoEquation()

_IN_PROGRESS = object()


class AttributeCycle(Exception):
    """An attribute depends on itself.  ``chain`` is the list of (attribute
    name, node) requests on the cycle, ending with the one that closed it."""

    def __init__(self, chain):
        self.chain = chain
        super().__init__('attribute cycle: ' + ' -> '.join(
            '%s at %s' % (name, getattr(node, 'name', node)) for name, node in chain))


class Attribute:
    SYN = 'syn'
    INH = 'inh'

    def __init__(self, name, kind, equation):
        self.name = name
        self.kind = kind
        self.equation = equation

    def __call__(self, node):
        """The value of this attribute at an AttrNode."""
        return node.tree.get(node, self)

    def __repr__(self):
        return '<%s attribute %s>' % (self.kind, self.name)


def syn(equation):
    """Decorator: a synthesized attribute named after the function."""
    return Attribute(equation.__name__, Attribute.SYN, equation)


def inh(equation):
    """Decorator: an inherited attribute named after the function."""
    return Attribute(equation.__name__, Attribute.INH, equation)


class AttrNode:
    """A node of an AttrTree: one occurrence of a node of the parsed tree."""

    __slots__ = ('tree', 'node', 'parent', 'index', 'children', '_values')

    def __init__(self, tree, node, parent, index):
        self.tree = tree
        self.node = node
        self.parent = parent
        self.index = index
        self.children = []
        self._values = {}

    def __getattr__(self, name):
        return getattr(self.node, name)

    def __repr__(self):
        return 'AttrNode(%r)' % (self.node,)


class AttrTree:
    """Attributes over the tree under ``root``.  ``children(node)`` gives a
    node's children (by default ``node.children``).  A node reached from
    several parents gets a separate AttrNode for each occurrence."""

    def __init__(self, root, children=None):
        get_children = children or (lambda n: n.children)
        self._stack = []
        self.root = AttrNode(self, root, None, -1)
        todo = [self.root]
        while todo:
            a = todo.pop()
            a.children = [AttrNode(self, c, a, i) for i, c in enumerate(get_children(a.node))]
            todo.extend(a.children)

    def get(self, node, attr):
        values = node._values
        if attr in values:
            v = values[attr]
            if v is _IN_PROGRESS:
                start = next(i for i, (a, n) in enumerate(self._stack) if a is attr and n is node)
                chain = [(a.name, n.node) for a, n in self._stack[start:]] + [(attr.name, node.node)]
                raise AttributeCycle(chain)
            return v
        values[attr] = _IN_PROGRESS
        self._stack.append((attr, node))
        try:
            if attr.kind == Attribute.SYN:
                v = attr.equation(node)
                v = None if v is NO_EQUATION else v
            elif node.parent is None:
                v = attr.equation(node, -1)
                v = None if v is NO_EQUATION else v
            else:
                v = attr.equation(node.parent, node.index)
                if v is NO_EQUATION:
                    v = self.get(node.parent, attr)
        except BaseException:
            del values[attr]
            raise
        finally:
            self._stack.pop()
        values[attr] = v
        return v

    def nodes(self):
        """All AttrNodes, parents before children."""
        todo = [self.root]
        while todo:
            n = todo.pop()
            yield n
            todo.extend(reversed(n.children))
