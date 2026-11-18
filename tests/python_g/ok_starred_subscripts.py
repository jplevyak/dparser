x: tuple[*Ts]
y = A[float, *tuple[int, ...]]
z = Union[*args, *(kwargs.values())]
