# Roadmap

Known issues and ideas for future work.

* Fix issues with terminal priority when the different parses are coming from different states.
* Fix ambiguity handling for parsing from start states... Need to force a final reduction, either bloat the state table (probably best), or try to force the reduction manually.
* Memory leaks on error recovery.
* Enhance `cmp_stacks`.
* Optimize speed.
* Handle path for include files.
* Fix issue with `equiv_D_Scope`.
* Maybe:
  *  LALR.
  *  Error repair a la Carl Cerecke.
  *  Split global state on demand.
  *  Let whitespace change the threaded state, not only read it.
  *  A post-parse attribute library (Part B of `proposals/threaded-state-and-attributes.md`).
  *  Eager parser.
