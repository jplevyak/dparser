//! `whitespace.rs`
//! The default whitespace function (`white_space` in parse.c): skips blanks,
//! newlines, `//` and nested `/* */` comments, and `#line` directives.

use crate::types::Loc;

/// Whitespace characters, not including newline.
#[inline]
pub fn is_wspace(c: u8) -> bool {
    matches!(c, b'\t' | 0x0b | 0x0c | b'\r' | b' ')
}

/// Skip whitespace in `input[..end]` starting at `loc`, updating the line and
/// column.  `loc.ws` is left unchanged.
pub fn white_space(input: &[u8], end: usize, loc: &mut Loc) {
    // the character at s, or 0 at or beyond the end of the input
    let ch = |s: usize| -> u8 { if s < end { input[s] } else { 0 } };
    let mut s = loc.s;
    let mut scol: Option<usize> = None;
    let mut rec = 0u32;

    // A directive (`# 12 "file"` or `#line 12`) is only recognized at the
    // start of a line; returns false (and leaves s) if this '#' isn't one.
    let directive = |s: &mut usize, loc: &mut Loc| -> bool {
        let save = *s;
        *s += 1;
        while is_wspace(ch(*s)) {
            *s += 1;
        }
        if end >= *s + 4 && &input[*s..*s + 4] == b"line" && is_wspace(ch(*s + 4)) {
            *s += 5;
            while is_wspace(ch(*s)) {
                *s += 1;
            }
        }
        if ch(*s).is_ascii_digit() {
            let mut line: u32 = 0;
            while ch(*s).is_ascii_digit() {
                line = line.wrapping_mul(10).wrapping_add((ch(*s) - b'0') as u32);
                *s += 1;
            }
            loc.line = line.wrapping_sub(1);
            while ch(*s) != 0 && ch(*s) != b'\n' {
                *s += 1;
            }
            true
        } else {
            *s = save;
            false
        }
    };

    'done: {
        if ch(s) == b'#' && loc.col == 0 && !directive(&mut s, loc) {
            break 'done;
        }
        'more: loop {
            while is_wspace(ch(s)) {
                s += 1;
            }
            if ch(s) == b'\n' {
                loc.line = loc.line.wrapping_add(1);
                scol = Some(s + 1);
                s += 1;
                if ch(s) == b'#' && !directive(&mut s, loc) {
                    break 'done;
                }
                continue 'more;
            }
            if ch(s) == b'/' {
                if ch(s + 1) == b'/' {
                    while ch(s) != 0 && ch(s) != b'\n' {
                        s += 1;
                    }
                    continue 'more;
                }
                if ch(s + 1) == b'*' {
                    s += 2;
                    rec += 1;
                    while ch(s) != 0 {
                        if ch(s) == b'*' && ch(s + 1) == b'/' {
                            s += 2;
                            rec -= 1;
                            if rec == 0 {
                                continue 'more;
                            }
                            continue;
                        }
                        if ch(s) == b'/' && ch(s + 1) == b'*' {
                            s += 2;
                            rec += 1;
                            continue;
                        }
                        if ch(s) == b'\n' {
                            loc.line = loc.line.wrapping_add(1);
                            scol = Some(s + 1);
                        }
                        s += 1;
                    }
                }
            }
            break 'more;
        }
    }
    if let Some(sc) = scol {
        loc.col = (s - sc) as u32;
    } else {
        loc.col += (s - loc.s) as u32;
    }
    loc.s = s;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn at(input: &[u8]) -> Loc {
        let mut loc = Loc { s: 0, ws: 0, line: 1, col: 0 };
        white_space(input, input.len(), &mut loc);
        loc
    }

    #[test]
    fn blanks_and_newlines() {
        let loc = at(b" \t \n  x");
        assert_eq!((loc.s, loc.line, loc.col), (6, 2, 2));
    }

    #[test]
    fn nested_comments() {
        let input = b"/* this is /* nested */ comment */  test";
        let loc = at(input);
        assert_eq!(input[loc.s], b't');
    }

    #[test]
    fn line_directives() {
        let loc = at(b"# 10 \"f.c\"\nx");
        assert_eq!((loc.s, loc.line), (11, 10));
        let loc = at(b"#line 7\nx");
        assert_eq!((loc.s, loc.line), (8, 7));
    }

    #[test]
    fn hash_that_is_not_a_directive_is_not_skipped() {
        let loc = at(b"#define x");
        assert_eq!(loc.s, 0);
        let loc = at(b"a\n#define x");
        assert_eq!(loc.s, 0);
        let loc = at(b"  \n#define x");
        assert_eq!((loc.s, loc.line), (3, 2));
    }

    #[test]
    fn stops_at_end() {
        let mut loc = Loc { s: 0, ws: 0, line: 1, col: 0 };
        white_space(b"  /* x", 6, &mut loc);
        assert_eq!(loc.s, 6);
    }
}
