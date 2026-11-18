a = f'{x}' f"{y}" f'''{z}''' f"""{w}"""
b = f'{"a" if x else 'b'}'
c = f'{f'{f'{1}'}'}'
d = f'{x:{y}.{z}}' + f'{x!r:>{w}}' + f'{x!r:{y!s:>3}}'
e = f'{x=}' + f'{x = !r:10}' + f'{x=!r}'
g = f'{x:=10}' + f'{x:=^10}' + f'{x:%H:%M}' + f'{x:#x}'
h = f'{{}}' + f'{x}}}' + f'{x:}}}' + f'{x:{{}}}'
i = f'\{x}' + f'\N{EM DASH}' + rf'\N{x}' + f'#{x}' + f'{x}#'
j = f'{(lambda x: 1)}' + f'{x:}' + f'{ x }' + f'{x!r }' + f'{*a,}' + f'{a, b}'
k = f'{x:{y:{z}}}' + f'{x:{y:{z:w}}}' + f'{x:{f'{y:{z:{w}}}'}}'
l = f'{x
}' + f'{x #comment
}' + f'''{
x
}'''
m = f'''a'{x}'b''' + f'''a''{x}''b''' + f'''{x:'}''' + f'''{x:''}'''
n = f'{a["b"]}' + f'{ {'a': 1}['a'] }' + f'{[lambda: 1]}' + f'{(lambda: 1)()}'
o = f"\x1b]8;;\x1b\\{r}\x1b]8;;\x1b\\"
p = F'{x}' Rf'{y}' fR'{z}' 'plain' f'more'
q = t'{x!r:>10}' t'b' T'{y}'
r = rb'a' Br'b' b'\xe9'
