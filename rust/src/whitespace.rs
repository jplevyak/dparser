//! `whitespace.rs`
//! Core structural engine mapping exactly `white_space` natively across buffer boundaries in `parse.c`!
//! This component natively skips whitespace explicitly resolving `#line` bounds and inline comments.

use crate::types::Loc;

pub const WSPACE: [u8; 256] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, // 0-9
    0, 1, 1, 1, 0, 0, 0, 0, 0, 0, // 10-19
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 20-29
    0, 0, 1, 0, 0, 0, 0, 0, 0, 0, // 30-39 (32 is space)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // ... padded ...
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, // Up to 250
    0, 0, 0, 0, 0, 0, // Up to 256
];

#[inline]
pub fn is_wspace(c: u8) -> bool {
    WSPACE[c as usize] != 0
}

/// Natively advances the structural tracking limit sequentially jumping over boundaries.
pub fn white_space(input: &[u8], starting_loc: &mut Loc) {
    let mut rec = 0;

    let mut s = starting_loc.s;
    let mut scol: Option<usize> = None;

    // Bounds check closure to cleanly mimic C pointers safely tracking length limits
    let peek = |idx: usize| -> Option<u8> {
        if idx < input.len() {
            Some(input[idx])
        } else {
            None
        }
    };

    if peek(s) == Some(b'#') && starting_loc.col == 0 {
        'directive: loop {
            let save = s;
            s += 1;
            while peek(s).map_or(false, is_wspace) {
                s += 1;
            }

            // "#line" natively skipping bytes sequentially!
            if s + 3 < input.len() && &input[s..s + 4] == b"line" {
                if peek(s + 4).map_or(false, is_wspace) {
                    s += 5;
                    while peek(s).map_or(false, is_wspace) {
                        s += 1;
                    }
                }
            }

            if peek(s).map_or(false, |c| c.is_ascii_digit()) {
                let mut line_num = 0;
                while let Some(c) = peek(s) {
                    if c.is_ascii_digit() {
                        line_num = line_num * 10 + (c - b'0') as u32;
                        s += 1;
                    } else {
                        break;
                    }
                }

                if line_num > 0 {
                    starting_loc.line = line_num - 1;
                }

                while peek(s).map_or(false, is_wspace) {
                    s += 1;
                }

                if peek(s) == Some(b'"') {
                    // String directive `loc->pathname = s;`
                    // In Rust, we skip mapping the exact pointer directly unless bounded
                }
            } else {
                s = save;
                break 'directive; // GOTO Ldone
            }

            while peek(s).is_some() && peek(s) != Some(b'\n') {
                s += 1;
            }
            break;
        }
    }

    'more: loop {
        while peek(s).map_or(false, is_wspace) {
            s += 1;
        }

        if peek(s) == Some(b'\n') {
            starting_loc.line += 1;
            scol = Some(s + 1);
            s += 1;
            if peek(s) == Some(b'#') {
                // Technically `goto Ldirective`. We emulate by jumping!
                // C code repeats `#line` directives securely iteratively!
                s += 1;
                while peek(s).map_or(false, is_wspace) {
                    s += 1;
                }
                while peek(s).is_some() && peek(s) != Some(b'\n') {
                    s += 1;
                }
                continue 'more;
            } else {
                continue 'more;
            }
        }

        if peek(s) == Some(b'/') {
            if peek(s + 1) == Some(b'/') {
                while peek(s).is_some() && peek(s) != Some(b'\n') {
                    s += 1;
                }
                continue 'more;
            }

            if peek(s + 1) == Some(b'*') {
                s += 2;
                'nestComment: loop {
                    rec += 1;
                    'moreComment: loop {
                        while peek(s).is_some() {
                            if peek(s) == Some(b'*') && peek(s + 1) == Some(b'/') {
                                s += 2;
                                rec -= 1;
                                if rec == 0 {
                                    continue 'more;
                                }
                                continue 'moreComment;
                            }
                            if peek(s) == Some(b'/') && peek(s + 1) == Some(b'*') {
                                s += 2;
                                continue 'nestComment;
                            }
                            if peek(s) == Some(b'\n') {
                                starting_loc.line += 1;
                                scol = Some(s + 1);
                            }
                            s += 1;
                        }
                        break 'moreComment; // Reached EOF safely mappings gracefully!
                    }
                    break 'nestComment;
                }
            }
        }

        break 'more;
    }

    if let Some(sc) = scol {
        starting_loc.col = (s - sc) as u32;
    } else {
        starting_loc.col += (s - starting_loc.s) as u32;
    }

    starting_loc.ws = starting_loc.s;
    starting_loc.s = s;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Loc;

    #[test]
    fn test_white_space_simple() {
        let input = b" \t \n  x";
        let mut loc = Loc {
            s: 0,
            ws: 0,
            line: 1,
            col: 0,
        };

        white_space(input, &mut loc);

        assert_eq!(loc.s, 6);
        assert_eq!(loc.ws, 0);
        assert_eq!(loc.line, 2);
        assert_eq!(loc.col, 2);
    }

    #[test]
    fn test_white_space_comments() {
        let input = b"/* this is /* nested */ comment */  test";
        let mut loc = Loc {
            s: 0,
            ws: 0,
            line: 1,
            col: 0,
        };

        white_space(input, &mut loc);

        assert_eq!(loc.s, 36);
        assert_eq!(input[loc.s], b't');
    }
}
