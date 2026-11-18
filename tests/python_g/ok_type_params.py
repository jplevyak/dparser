def override[F: _Func](method: F, /) -> F: pass
def f[T, *Ts, **P](x: T, *a: *Ts) -> None: pass
class A[T: (int, str), U: int = int]: pass
class B[*Ts = *tuple[int], **P = [int, str]]: pass
type Alias[T = int] = list[T]
