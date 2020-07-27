# TO DO

* Fix issues with terminal priority when the different parses are coming from different states.... what does this mean?
* Fix ambiguity handling for parsing from start states... Need to force a final reduction, either bloat the state table (probably best), or try to force the reduction manually.
* Memory leaks on error recovery.
* Add trailing context to regular expressions.
* Enhance `cmp_stacks`.
* Optimize speed.
* Handle path for include files.
* Add option to name the output file -- *TODO: isn't this already done*?
* Fix issue with `equiv_D_Scope`.
* Maybe:
  *  LALR.
  *  Error repair a la Carl Cerecke.
  *  Split global state on demand.
  *  Ensure that states only summarize identical `.scope`, `.globals` and `.skip_space`.
  *  Eager parser.

## FIXME

I understand `make_dparser` already has an option to name the output file, right?
```
-o, --output  string  (null)  Output file name
```
