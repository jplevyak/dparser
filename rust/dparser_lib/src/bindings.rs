/* automatically generated by rust-bindgen 0.71.1 */

#![allow(
    non_upper_case_globals,
    non_camel_case_types,
    non_snake_case,
    dead_code
)]

#[repr(C)]
#[derive(Copy, Clone, Debug, Default, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct __BindgenBitfieldUnit<Storage> {
    storage: Storage,
}
impl<Storage> __BindgenBitfieldUnit<Storage> {
    #[inline]
    pub const fn new(storage: Storage) -> Self {
        Self { storage }
    }
}
impl<Storage> __BindgenBitfieldUnit<Storage>
where
    Storage: AsRef<[u8]> + AsMut<[u8]>,
{
    #[inline]
    fn extract_bit(byte: u8, index: usize) -> bool {
        let bit_index = if cfg!(target_endian = "big") {
            7 - (index % 8)
        } else {
            index % 8
        };
        let mask = 1 << bit_index;
        byte & mask == mask
    }
    #[inline]
    pub fn get_bit(&self, index: usize) -> bool {
        debug_assert!(index / 8 < self.storage.as_ref().len());
        let byte_index = index / 8;
        let byte = self.storage.as_ref()[byte_index];
        Self::extract_bit(byte, index)
    }
    #[inline]
    pub fn raw_get_bit(this: *const Self, index: usize) -> bool {
        debug_assert!(index / 8 < core::mem::size_of::<Storage>());
        unsafe {
            let byte_index = index / 8;
            let byte =
                *(core::ptr::addr_of!((*this).storage) as *const u8).offset(byte_index as isize);
            Self::extract_bit(byte, index)
        }
    }
    #[inline]
    fn change_bit(byte: u8, index: usize, val: bool) -> u8 {
        let bit_index = if cfg!(target_endian = "big") {
            7 - (index % 8)
        } else {
            index % 8
        };
        let mask = 1 << bit_index;
        if val {
            byte | mask
        } else {
            byte & !mask
        }
    }
    #[inline]
    pub fn set_bit(&mut self, index: usize, val: bool) {
        debug_assert!(index / 8 < self.storage.as_ref().len());
        let byte_index = index / 8;
        let byte = &mut self.storage.as_mut()[byte_index];
        *byte = Self::change_bit(*byte, index, val);
    }
    #[inline]
    pub fn raw_set_bit(this: *mut Self, index: usize, val: bool) {
        debug_assert!(index / 8 < core::mem::size_of::<Storage>());
        unsafe {
            let byte_index = index / 8;
            let byte =
                (core::ptr::addr_of_mut!((*this).storage) as *mut u8).offset(byte_index as isize);
            *byte = Self::change_bit(*byte, index, val);
        }
    }
    #[inline]
    pub fn get(&self, bit_offset: usize, bit_width: u8) -> u64 {
        debug_assert!(bit_width <= 64);
        debug_assert!(bit_offset / 8 < self.storage.as_ref().len());
        debug_assert!((bit_offset + (bit_width as usize)) / 8 <= self.storage.as_ref().len());
        let mut val = 0;
        for i in 0..(bit_width as usize) {
            if self.get_bit(i + bit_offset) {
                let index = if cfg!(target_endian = "big") {
                    bit_width as usize - 1 - i
                } else {
                    i
                };
                val |= 1 << index;
            }
        }
        val
    }
    #[inline]
    pub unsafe fn raw_get(this: *const Self, bit_offset: usize, bit_width: u8) -> u64 {
        debug_assert!(bit_width <= 64);
        debug_assert!(bit_offset / 8 < core::mem::size_of::<Storage>());
        debug_assert!((bit_offset + (bit_width as usize)) / 8 <= core::mem::size_of::<Storage>());
        let mut val = 0;
        for i in 0..(bit_width as usize) {
            if Self::raw_get_bit(this, i + bit_offset) {
                let index = if cfg!(target_endian = "big") {
                    bit_width as usize - 1 - i
                } else {
                    i
                };
                val |= 1 << index;
            }
        }
        val
    }
    #[inline]
    pub fn set(&mut self, bit_offset: usize, bit_width: u8, val: u64) {
        debug_assert!(bit_width <= 64);
        debug_assert!(bit_offset / 8 < self.storage.as_ref().len());
        debug_assert!((bit_offset + (bit_width as usize)) / 8 <= self.storage.as_ref().len());
        for i in 0..(bit_width as usize) {
            let mask = 1 << i;
            let val_bit_is_set = val & mask == mask;
            let index = if cfg!(target_endian = "big") {
                bit_width as usize - 1 - i
            } else {
                i
            };
            self.set_bit(index + bit_offset, val_bit_is_set);
        }
    }
    #[inline]
    pub unsafe fn raw_set(this: *mut Self, bit_offset: usize, bit_width: u8, val: u64) {
        debug_assert!(bit_width <= 64);
        debug_assert!(bit_offset / 8 < core::mem::size_of::<Storage>());
        debug_assert!((bit_offset + (bit_width as usize)) / 8 <= core::mem::size_of::<Storage>());
        for i in 0..(bit_width as usize) {
            let mask = 1 << i;
            let val_bit_is_set = val & mask == mask;
            let index = if cfg!(target_endian = "big") {
                bit_width as usize - 1 - i
            } else {
                i
            };
            Self::raw_set_bit(this, index + bit_offset, val_bit_is_set);
        }
    }
}
pub const SCANNER_BLOCKS_POW2: u32 = 2;
pub const SCANNER_BLOCKS: u32 = 4;
pub const SCANNER_BLOCK_SHIFT: u32 = 6;
pub const SCANNER_BLOCK_MASK: u32 = 63;
pub const SCANNER_BLOCK_SIZE: u32 = 64;
pub const D_SCAN_ALL: u32 = 0;
pub const D_SCAN_LONGEST: u32 = 1;
pub const D_SCAN_MIXED: u32 = 2;
pub const D_SCAN_TRAILING: u32 = 3;
pub const D_SCAN_RESERVED: u32 = 4;
pub const D_SCAN_DEFAULT: u32 = 0;
pub const D_SYMBOL_NTERM: u32 = 1;
pub const D_SYMBOL_INTERNAL: u32 = 2;
pub const D_SYMBOL_EBNF: u32 = 3;
pub const D_SYMBOL_STRING: u32 = 4;
pub const D_SYMBOL_REGEX: u32 = 5;
pub const D_SYMBOL_CODE: u32 = 6;
pub const D_SYMBOL_TOKEN: u32 = 7;
pub const D_PASS_PRE_ORDER: u32 = 1;
pub const D_PASS_POST_ORDER: u32 = 2;
pub const D_PASS_MANUAL: u32 = 4;
pub const D_PASS_FOR_ALL: u32 = 8;
pub const D_PASS_FOR_UNDEFINED: u32 = 16;
pub const D_SCOPE_INHERIT: u32 = 0;
pub const D_SCOPE_RECURSIVE: u32 = 1;
pub const D_SCOPE_PARALLEL: u32 = 2;
pub const D_SCOPE_SEQUENTIAL: u32 = 3;
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_ShiftTable {
    _unused: [u8; 0],
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct d_loc_t {
    pub s: *mut ::std::os::raw::c_char,
    pub pathname: *mut ::std::os::raw::c_char,
    pub ws: *mut ::std::os::raw::c_char,
    pub col: ::std::os::raw::c_int,
    pub line: ::std::os::raw::c_int,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of d_loc_t"][::std::mem::size_of::<d_loc_t>() - 32usize];
    ["Alignment of d_loc_t"][::std::mem::align_of::<d_loc_t>() - 8usize];
    ["Offset of field: d_loc_t::s"][::std::mem::offset_of!(d_loc_t, s) - 0usize];
    ["Offset of field: d_loc_t::pathname"][::std::mem::offset_of!(d_loc_t, pathname) - 8usize];
    ["Offset of field: d_loc_t::ws"][::std::mem::offset_of!(d_loc_t, ws) - 16usize];
    ["Offset of field: d_loc_t::col"][::std::mem::offset_of!(d_loc_t, col) - 24usize];
    ["Offset of field: d_loc_t::line"][::std::mem::offset_of!(d_loc_t, line) - 28usize];
};
pub type D_WhiteSpaceFn = ::std::option::Option<
    unsafe extern "C" fn(
        p: *mut D_Parser,
        loc: *mut d_loc_t,
        p_globals: *mut *mut ::std::os::raw::c_void,
    ),
>;
pub type D_ScanCode = ::std::option::Option<
    unsafe extern "C" fn(
        loc: *mut d_loc_t,
        symbol: *mut ::std::os::raw::c_ushort,
        term_priority: *mut ::std::os::raw::c_int,
        op_assoc: *mut ::std::os::raw::c_uchar,
        op_priority: *mut ::std::os::raw::c_int,
    ) -> ::std::os::raw::c_int,
>;
pub type D_ReductionCode = ::std::option::Option<
    unsafe extern "C" fn(
        new_ps: *mut ::std::os::raw::c_void,
        children: *mut *mut ::std::os::raw::c_void,
        n_children: ::std::os::raw::c_int,
        pn_offset: ::std::os::raw::c_int,
        parser: *mut D_Parser,
    ) -> ::std::os::raw::c_int,
>;
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Reduction {
    pub nelements: ::std::os::raw::c_ushort,
    pub symbol: ::std::os::raw::c_ushort,
    pub speculative_code: D_ReductionCode,
    pub final_code: D_ReductionCode,
    pub op_assoc: ::std::os::raw::c_ushort,
    pub rule_assoc: ::std::os::raw::c_ushort,
    pub op_priority: ::std::os::raw::c_int,
    pub rule_priority: ::std::os::raw::c_int,
    pub action_index: ::std::os::raw::c_int,
    pub npass_code: ::std::os::raw::c_int,
    pub pass_code: *mut D_ReductionCode,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_Reduction"][::std::mem::size_of::<D_Reduction>() - 56usize];
    ["Alignment of D_Reduction"][::std::mem::align_of::<D_Reduction>() - 8usize];
    ["Offset of field: D_Reduction::nelements"]
        [::std::mem::offset_of!(D_Reduction, nelements) - 0usize];
    ["Offset of field: D_Reduction::symbol"][::std::mem::offset_of!(D_Reduction, symbol) - 2usize];
    ["Offset of field: D_Reduction::speculative_code"]
        [::std::mem::offset_of!(D_Reduction, speculative_code) - 8usize];
    ["Offset of field: D_Reduction::final_code"]
        [::std::mem::offset_of!(D_Reduction, final_code) - 16usize];
    ["Offset of field: D_Reduction::op_assoc"]
        [::std::mem::offset_of!(D_Reduction, op_assoc) - 24usize];
    ["Offset of field: D_Reduction::rule_assoc"]
        [::std::mem::offset_of!(D_Reduction, rule_assoc) - 26usize];
    ["Offset of field: D_Reduction::op_priority"]
        [::std::mem::offset_of!(D_Reduction, op_priority) - 28usize];
    ["Offset of field: D_Reduction::rule_priority"]
        [::std::mem::offset_of!(D_Reduction, rule_priority) - 32usize];
    ["Offset of field: D_Reduction::action_index"]
        [::std::mem::offset_of!(D_Reduction, action_index) - 36usize];
    ["Offset of field: D_Reduction::npass_code"]
        [::std::mem::offset_of!(D_Reduction, npass_code) - 40usize];
    ["Offset of field: D_Reduction::pass_code"]
        [::std::mem::offset_of!(D_Reduction, pass_code) - 48usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_RightEpsilonHint {
    pub depth: ::std::os::raw::c_ushort,
    pub preceeding_state: ::std::os::raw::c_ushort,
    pub reduction: *mut D_Reduction,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_RightEpsilonHint"][::std::mem::size_of::<D_RightEpsilonHint>() - 16usize];
    ["Alignment of D_RightEpsilonHint"][::std::mem::align_of::<D_RightEpsilonHint>() - 8usize];
    ["Offset of field: D_RightEpsilonHint::depth"]
        [::std::mem::offset_of!(D_RightEpsilonHint, depth) - 0usize];
    ["Offset of field: D_RightEpsilonHint::preceeding_state"]
        [::std::mem::offset_of!(D_RightEpsilonHint, preceeding_state) - 2usize];
    ["Offset of field: D_RightEpsilonHint::reduction"]
        [::std::mem::offset_of!(D_RightEpsilonHint, reduction) - 8usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_ErrorRecoveryHint {
    pub depth: ::std::os::raw::c_ushort,
    pub symbol: ::std::os::raw::c_ushort,
    pub string: *const ::std::os::raw::c_char,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_ErrorRecoveryHint"][::std::mem::size_of::<D_ErrorRecoveryHint>() - 16usize];
    ["Alignment of D_ErrorRecoveryHint"][::std::mem::align_of::<D_ErrorRecoveryHint>() - 8usize];
    ["Offset of field: D_ErrorRecoveryHint::depth"]
        [::std::mem::offset_of!(D_ErrorRecoveryHint, depth) - 0usize];
    ["Offset of field: D_ErrorRecoveryHint::symbol"]
        [::std::mem::offset_of!(D_ErrorRecoveryHint, symbol) - 2usize];
    ["Offset of field: D_ErrorRecoveryHint::string"]
        [::std::mem::offset_of!(D_ErrorRecoveryHint, string) - 8usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Shift {
    pub symbol: ::std::os::raw::c_ushort,
    pub shift_kind: ::std::os::raw::c_uchar,
    pub op_assoc: ::std::os::raw::c_uchar,
    pub op_priority: ::std::os::raw::c_int,
    pub term_priority: ::std::os::raw::c_int,
    pub action_index: ::std::os::raw::c_int,
    pub speculative_code: D_ReductionCode,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_Shift"][::std::mem::size_of::<D_Shift>() - 24usize];
    ["Alignment of D_Shift"][::std::mem::align_of::<D_Shift>() - 8usize];
    ["Offset of field: D_Shift::symbol"][::std::mem::offset_of!(D_Shift, symbol) - 0usize];
    ["Offset of field: D_Shift::shift_kind"][::std::mem::offset_of!(D_Shift, shift_kind) - 2usize];
    ["Offset of field: D_Shift::op_assoc"][::std::mem::offset_of!(D_Shift, op_assoc) - 3usize];
    ["Offset of field: D_Shift::op_priority"]
        [::std::mem::offset_of!(D_Shift, op_priority) - 4usize];
    ["Offset of field: D_Shift::term_priority"]
        [::std::mem::offset_of!(D_Shift, term_priority) - 8usize];
    ["Offset of field: D_Shift::action_index"]
        [::std::mem::offset_of!(D_Shift, action_index) - 12usize];
    ["Offset of field: D_Shift::speculative_code"]
        [::std::mem::offset_of!(D_Shift, speculative_code) - 16usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct SB_uint8 {
    pub shift: *mut *mut D_Shift,
    pub scanner_block: [*mut ::std::os::raw::c_uchar; 4usize],
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of SB_uint8"][::std::mem::size_of::<SB_uint8>() - 40usize];
    ["Alignment of SB_uint8"][::std::mem::align_of::<SB_uint8>() - 8usize];
    ["Offset of field: SB_uint8::shift"][::std::mem::offset_of!(SB_uint8, shift) - 0usize];
    ["Offset of field: SB_uint8::scanner_block"]
        [::std::mem::offset_of!(SB_uint8, scanner_block) - 8usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct SB_uint16 {
    pub shift: *mut *mut D_Shift,
    pub scanner_block: [*mut ::std::os::raw::c_ushort; 4usize],
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of SB_uint16"][::std::mem::size_of::<SB_uint16>() - 40usize];
    ["Alignment of SB_uint16"][::std::mem::align_of::<SB_uint16>() - 8usize];
    ["Offset of field: SB_uint16::shift"][::std::mem::offset_of!(SB_uint16, shift) - 0usize];
    ["Offset of field: SB_uint16::scanner_block"]
        [::std::mem::offset_of!(SB_uint16, scanner_block) - 8usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct SB_uint32 {
    pub shift: *mut *mut D_Shift,
    pub scanner_block: [*mut ::std::os::raw::c_uint; 4usize],
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of SB_uint32"][::std::mem::size_of::<SB_uint32>() - 40usize];
    ["Alignment of SB_uint32"][::std::mem::align_of::<SB_uint32>() - 8usize];
    ["Offset of field: SB_uint32::shift"][::std::mem::offset_of!(SB_uint32, shift) - 0usize];
    ["Offset of field: SB_uint32::scanner_block"]
        [::std::mem::offset_of!(SB_uint32, scanner_block) - 8usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct SB_trans_uint8 {
    pub scanner_block: [*mut ::std::os::raw::c_uchar; 4usize],
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of SB_trans_uint8"][::std::mem::size_of::<SB_trans_uint8>() - 32usize];
    ["Alignment of SB_trans_uint8"][::std::mem::align_of::<SB_trans_uint8>() - 8usize];
    ["Offset of field: SB_trans_uint8::scanner_block"]
        [::std::mem::offset_of!(SB_trans_uint8, scanner_block) - 0usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct SB_trans_uint16 {
    pub scanner_block: [*mut ::std::os::raw::c_ushort; 4usize],
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of SB_trans_uint16"][::std::mem::size_of::<SB_trans_uint16>() - 32usize];
    ["Alignment of SB_trans_uint16"][::std::mem::align_of::<SB_trans_uint16>() - 8usize];
    ["Offset of field: SB_trans_uint16::scanner_block"]
        [::std::mem::offset_of!(SB_trans_uint16, scanner_block) - 0usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct SB_trans_uint32 {
    pub scanner_block: [*mut ::std::os::raw::c_uint; 4usize],
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of SB_trans_uint32"][::std::mem::size_of::<SB_trans_uint32>() - 32usize];
    ["Alignment of SB_trans_uint32"][::std::mem::align_of::<SB_trans_uint32>() - 8usize];
    ["Offset of field: SB_trans_uint32::scanner_block"]
        [::std::mem::offset_of!(SB_trans_uint32, scanner_block) - 0usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_State {
    pub goto_valid: *mut ::std::os::raw::c_uchar,
    pub goto_table_offset: ::std::os::raw::c_int,
    pub reductions: D_State__bindgen_ty_1,
    pub right_epsilon_hints: D_State__bindgen_ty_2,
    pub error_recovery_hints: D_State__bindgen_ty_3,
    pub shifts: ::std::os::raw::c_int,
    pub scanner_code: D_ScanCode,
    pub scanner_table: *mut ::std::os::raw::c_void,
    pub scanner_size: ::std::os::raw::c_uchar,
    pub accept: ::std::os::raw::c_uchar,
    pub scan_kind: ::std::os::raw::c_uchar,
    pub transition_table: *mut ::std::os::raw::c_void,
    pub accepts_diff: *mut *mut *mut D_Shift,
    pub reduces_to: ::std::os::raw::c_int,
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_State__bindgen_ty_1 {
    pub n: ::std::os::raw::c_uint,
    pub v: *mut *mut D_Reduction,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_State__bindgen_ty_1"][::std::mem::size_of::<D_State__bindgen_ty_1>() - 16usize];
    ["Alignment of D_State__bindgen_ty_1"]
        [::std::mem::align_of::<D_State__bindgen_ty_1>() - 8usize];
    ["Offset of field: D_State__bindgen_ty_1::n"]
        [::std::mem::offset_of!(D_State__bindgen_ty_1, n) - 0usize];
    ["Offset of field: D_State__bindgen_ty_1::v"]
        [::std::mem::offset_of!(D_State__bindgen_ty_1, v) - 8usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_State__bindgen_ty_2 {
    pub n: ::std::os::raw::c_uint,
    pub v: *mut D_RightEpsilonHint,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_State__bindgen_ty_2"][::std::mem::size_of::<D_State__bindgen_ty_2>() - 16usize];
    ["Alignment of D_State__bindgen_ty_2"]
        [::std::mem::align_of::<D_State__bindgen_ty_2>() - 8usize];
    ["Offset of field: D_State__bindgen_ty_2::n"]
        [::std::mem::offset_of!(D_State__bindgen_ty_2, n) - 0usize];
    ["Offset of field: D_State__bindgen_ty_2::v"]
        [::std::mem::offset_of!(D_State__bindgen_ty_2, v) - 8usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_State__bindgen_ty_3 {
    pub n: ::std::os::raw::c_uint,
    pub v: *mut D_ErrorRecoveryHint,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_State__bindgen_ty_3"][::std::mem::size_of::<D_State__bindgen_ty_3>() - 16usize];
    ["Alignment of D_State__bindgen_ty_3"]
        [::std::mem::align_of::<D_State__bindgen_ty_3>() - 8usize];
    ["Offset of field: D_State__bindgen_ty_3::n"]
        [::std::mem::offset_of!(D_State__bindgen_ty_3, n) - 0usize];
    ["Offset of field: D_State__bindgen_ty_3::v"]
        [::std::mem::offset_of!(D_State__bindgen_ty_3, v) - 8usize];
};
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_State"][::std::mem::size_of::<D_State>() - 120usize];
    ["Alignment of D_State"][::std::mem::align_of::<D_State>() - 8usize];
    ["Offset of field: D_State::goto_valid"][::std::mem::offset_of!(D_State, goto_valid) - 0usize];
    ["Offset of field: D_State::goto_table_offset"]
        [::std::mem::offset_of!(D_State, goto_table_offset) - 8usize];
    ["Offset of field: D_State::reductions"][::std::mem::offset_of!(D_State, reductions) - 16usize];
    ["Offset of field: D_State::right_epsilon_hints"]
        [::std::mem::offset_of!(D_State, right_epsilon_hints) - 32usize];
    ["Offset of field: D_State::error_recovery_hints"]
        [::std::mem::offset_of!(D_State, error_recovery_hints) - 48usize];
    ["Offset of field: D_State::shifts"][::std::mem::offset_of!(D_State, shifts) - 64usize];
    ["Offset of field: D_State::scanner_code"]
        [::std::mem::offset_of!(D_State, scanner_code) - 72usize];
    ["Offset of field: D_State::scanner_table"]
        [::std::mem::offset_of!(D_State, scanner_table) - 80usize];
    ["Offset of field: D_State::scanner_size"]
        [::std::mem::offset_of!(D_State, scanner_size) - 88usize];
    ["Offset of field: D_State::accept"][::std::mem::offset_of!(D_State, accept) - 89usize];
    ["Offset of field: D_State::scan_kind"][::std::mem::offset_of!(D_State, scan_kind) - 90usize];
    ["Offset of field: D_State::transition_table"]
        [::std::mem::offset_of!(D_State, transition_table) - 96usize];
    ["Offset of field: D_State::accepts_diff"]
        [::std::mem::offset_of!(D_State, accepts_diff) - 104usize];
    ["Offset of field: D_State::reduces_to"]
        [::std::mem::offset_of!(D_State, reduces_to) - 112usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Symbol {
    pub kind: ::std::os::raw::c_uint,
    pub name: *const ::std::os::raw::c_char,
    pub name_len: ::std::os::raw::c_int,
    pub start_symbol: ::std::os::raw::c_int,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_Symbol"][::std::mem::size_of::<D_Symbol>() - 24usize];
    ["Alignment of D_Symbol"][::std::mem::align_of::<D_Symbol>() - 8usize];
    ["Offset of field: D_Symbol::kind"][::std::mem::offset_of!(D_Symbol, kind) - 0usize];
    ["Offset of field: D_Symbol::name"][::std::mem::offset_of!(D_Symbol, name) - 8usize];
    ["Offset of field: D_Symbol::name_len"][::std::mem::offset_of!(D_Symbol, name_len) - 16usize];
    ["Offset of field: D_Symbol::start_symbol"]
        [::std::mem::offset_of!(D_Symbol, start_symbol) - 20usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Pass {
    pub name: *mut ::std::os::raw::c_char,
    pub name_len: ::std::os::raw::c_uint,
    pub kind: ::std::os::raw::c_uint,
    pub index: ::std::os::raw::c_uint,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_Pass"][::std::mem::size_of::<D_Pass>() - 24usize];
    ["Alignment of D_Pass"][::std::mem::align_of::<D_Pass>() - 8usize];
    ["Offset of field: D_Pass::name"][::std::mem::offset_of!(D_Pass, name) - 0usize];
    ["Offset of field: D_Pass::name_len"][::std::mem::offset_of!(D_Pass, name_len) - 8usize];
    ["Offset of field: D_Pass::kind"][::std::mem::offset_of!(D_Pass, kind) - 12usize];
    ["Offset of field: D_Pass::index"][::std::mem::offset_of!(D_Pass, index) - 16usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_ParserTables {
    pub nstates: ::std::os::raw::c_uint,
    pub state: *mut D_State,
    pub goto_table: *mut ::std::os::raw::c_ushort,
    pub whitespace_state: ::std::os::raw::c_uint,
    pub nsymbols: ::std::os::raw::c_uint,
    pub symbols: *mut D_Symbol,
    pub default_white_space: D_WhiteSpaceFn,
    pub npasses: ::std::os::raw::c_uint,
    pub passes: *mut D_Pass,
    pub save_parse_tree: ::std::os::raw::c_uint,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_ParserTables"][::std::mem::size_of::<D_ParserTables>() - 72usize];
    ["Alignment of D_ParserTables"][::std::mem::align_of::<D_ParserTables>() - 8usize];
    ["Offset of field: D_ParserTables::nstates"]
        [::std::mem::offset_of!(D_ParserTables, nstates) - 0usize];
    ["Offset of field: D_ParserTables::state"]
        [::std::mem::offset_of!(D_ParserTables, state) - 8usize];
    ["Offset of field: D_ParserTables::goto_table"]
        [::std::mem::offset_of!(D_ParserTables, goto_table) - 16usize];
    ["Offset of field: D_ParserTables::whitespace_state"]
        [::std::mem::offset_of!(D_ParserTables, whitespace_state) - 24usize];
    ["Offset of field: D_ParserTables::nsymbols"]
        [::std::mem::offset_of!(D_ParserTables, nsymbols) - 28usize];
    ["Offset of field: D_ParserTables::symbols"]
        [::std::mem::offset_of!(D_ParserTables, symbols) - 32usize];
    ["Offset of field: D_ParserTables::default_white_space"]
        [::std::mem::offset_of!(D_ParserTables, default_white_space) - 40usize];
    ["Offset of field: D_ParserTables::npasses"]
        [::std::mem::offset_of!(D_ParserTables, npasses) - 48usize];
    ["Offset of field: D_ParserTables::passes"]
        [::std::mem::offset_of!(D_ParserTables, passes) - 56usize];
    ["Offset of field: D_ParserTables::save_parse_tree"]
        [::std::mem::offset_of!(D_ParserTables, save_parse_tree) - 64usize];
};
unsafe extern "C" {
    pub fn parse_whitespace(
        p: *mut D_Parser,
        loc: *mut d_loc_t,
        p_globals: *mut *mut ::std::os::raw::c_void,
    );
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_SymHash {
    _unused: [u8; 0],
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Sym {
    pub name: *mut ::std::os::raw::c_char,
    pub len: ::std::os::raw::c_int,
    pub hash: ::std::os::raw::c_uint,
    pub scope: *mut D_Scope,
    pub update_of: *mut D_Sym,
    pub next: *mut D_Sym,
    pub user: ::std::os::raw::c_uint,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_Sym"][::std::mem::size_of::<D_Sym>() - 48usize];
    ["Alignment of D_Sym"][::std::mem::align_of::<D_Sym>() - 8usize];
    ["Offset of field: D_Sym::name"][::std::mem::offset_of!(D_Sym, name) - 0usize];
    ["Offset of field: D_Sym::len"][::std::mem::offset_of!(D_Sym, len) - 8usize];
    ["Offset of field: D_Sym::hash"][::std::mem::offset_of!(D_Sym, hash) - 12usize];
    ["Offset of field: D_Sym::scope"][::std::mem::offset_of!(D_Sym, scope) - 16usize];
    ["Offset of field: D_Sym::update_of"][::std::mem::offset_of!(D_Sym, update_of) - 24usize];
    ["Offset of field: D_Sym::next"][::std::mem::offset_of!(D_Sym, next) - 32usize];
    ["Offset of field: D_Sym::user"][::std::mem::offset_of!(D_Sym, user) - 40usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Scope {
    pub _bitfield_align_1: [u8; 0],
    pub _bitfield_1: __BindgenBitfieldUnit<[u8; 1usize]>,
    pub depth: ::std::os::raw::c_uint,
    pub ll: *mut D_Sym,
    pub hash: *mut D_SymHash,
    pub updates: *mut D_Sym,
    pub search: *mut D_Scope,
    pub dynamic: *mut D_Scope,
    pub up: *mut D_Scope,
    pub up_updates: *mut D_Scope,
    pub down: *mut D_Scope,
    pub down_next: *mut D_Scope,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_Scope"][::std::mem::size_of::<D_Scope>() - 80usize];
    ["Alignment of D_Scope"][::std::mem::align_of::<D_Scope>() - 8usize];
    ["Offset of field: D_Scope::depth"][::std::mem::offset_of!(D_Scope, depth) - 4usize];
    ["Offset of field: D_Scope::ll"][::std::mem::offset_of!(D_Scope, ll) - 8usize];
    ["Offset of field: D_Scope::hash"][::std::mem::offset_of!(D_Scope, hash) - 16usize];
    ["Offset of field: D_Scope::updates"][::std::mem::offset_of!(D_Scope, updates) - 24usize];
    ["Offset of field: D_Scope::search"][::std::mem::offset_of!(D_Scope, search) - 32usize];
    ["Offset of field: D_Scope::dynamic"][::std::mem::offset_of!(D_Scope, dynamic) - 40usize];
    ["Offset of field: D_Scope::up"][::std::mem::offset_of!(D_Scope, up) - 48usize];
    ["Offset of field: D_Scope::up_updates"][::std::mem::offset_of!(D_Scope, up_updates) - 56usize];
    ["Offset of field: D_Scope::down"][::std::mem::offset_of!(D_Scope, down) - 64usize];
    ["Offset of field: D_Scope::down_next"][::std::mem::offset_of!(D_Scope, down_next) - 72usize];
};
impl D_Scope {
    #[inline]
    pub fn kind(&self) -> ::std::os::raw::c_uint {
        unsafe { ::std::mem::transmute(self._bitfield_1.get(0usize, 2u8) as u32) }
    }
    #[inline]
    pub fn set_kind(&mut self, val: ::std::os::raw::c_uint) {
        unsafe {
            let val: u32 = ::std::mem::transmute(val);
            self._bitfield_1.set(0usize, 2u8, val as u64)
        }
    }
    #[inline]
    pub unsafe fn kind_raw(this: *const Self) -> ::std::os::raw::c_uint {
        unsafe {
            ::std::mem::transmute(<__BindgenBitfieldUnit<[u8; 1usize]>>::raw_get(
                ::std::ptr::addr_of!((*this)._bitfield_1),
                0usize,
                2u8,
            ) as u32)
        }
    }
    #[inline]
    pub unsafe fn set_kind_raw(this: *mut Self, val: ::std::os::raw::c_uint) {
        unsafe {
            let val: u32 = ::std::mem::transmute(val);
            <__BindgenBitfieldUnit<[u8; 1usize]>>::raw_set(
                ::std::ptr::addr_of_mut!((*this)._bitfield_1),
                0usize,
                2u8,
                val as u64,
            )
        }
    }
    #[inline]
    pub fn owned_by_user(&self) -> ::std::os::raw::c_uint {
        unsafe { ::std::mem::transmute(self._bitfield_1.get(2usize, 1u8) as u32) }
    }
    #[inline]
    pub fn set_owned_by_user(&mut self, val: ::std::os::raw::c_uint) {
        unsafe {
            let val: u32 = ::std::mem::transmute(val);
            self._bitfield_1.set(2usize, 1u8, val as u64)
        }
    }
    #[inline]
    pub unsafe fn owned_by_user_raw(this: *const Self) -> ::std::os::raw::c_uint {
        unsafe {
            ::std::mem::transmute(<__BindgenBitfieldUnit<[u8; 1usize]>>::raw_get(
                ::std::ptr::addr_of!((*this)._bitfield_1),
                2usize,
                1u8,
            ) as u32)
        }
    }
    #[inline]
    pub unsafe fn set_owned_by_user_raw(this: *mut Self, val: ::std::os::raw::c_uint) {
        unsafe {
            let val: u32 = ::std::mem::transmute(val);
            <__BindgenBitfieldUnit<[u8; 1usize]>>::raw_set(
                ::std::ptr::addr_of_mut!((*this)._bitfield_1),
                2usize,
                1u8,
                val as u64,
            )
        }
    }
    #[inline]
    pub fn new_bitfield_1(
        kind: ::std::os::raw::c_uint,
        owned_by_user: ::std::os::raw::c_uint,
    ) -> __BindgenBitfieldUnit<[u8; 1usize]> {
        let mut __bindgen_bitfield_unit: __BindgenBitfieldUnit<[u8; 1usize]> = Default::default();
        __bindgen_bitfield_unit.set(0usize, 2u8, {
            let kind: u32 = unsafe { ::std::mem::transmute(kind) };
            kind as u64
        });
        __bindgen_bitfield_unit.set(2usize, 1u8, {
            let owned_by_user: u32 = unsafe { ::std::mem::transmute(owned_by_user) };
            owned_by_user as u64
        });
        __bindgen_bitfield_unit
    }
}
unsafe extern "C" {
    pub fn new_D_Scope(parent: *mut D_Scope) -> *mut D_Scope;
}
unsafe extern "C" {
    pub fn enter_D_Scope(current: *mut D_Scope, scope: *mut D_Scope) -> *mut D_Scope;
}
unsafe extern "C" {
    pub fn commit_D_Scope(scope: *mut D_Scope) -> *mut D_Scope;
}
unsafe extern "C" {
    pub fn equiv_D_Scope(scope: *mut D_Scope) -> *mut D_Scope;
}
unsafe extern "C" {
    pub fn global_D_Scope(scope: *mut D_Scope) -> *mut D_Scope;
}
unsafe extern "C" {
    pub fn scope_D_Scope(current: *mut D_Scope, scope: *mut D_Scope) -> *mut D_Scope;
}
unsafe extern "C" {
    pub fn free_D_Scope(st: *mut D_Scope, force: ::std::os::raw::c_int);
}
unsafe extern "C" {
    pub fn new_D_Sym(
        st: *mut D_Scope,
        name: *mut ::std::os::raw::c_char,
        end: *mut ::std::os::raw::c_char,
        sizeof_D_Sym: ::std::os::raw::c_int,
    ) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn find_D_Sym(
        st: *mut D_Scope,
        name: *mut ::std::os::raw::c_char,
        end: *mut ::std::os::raw::c_char,
    ) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn find_global_D_Sym(
        st: *mut D_Scope,
        name: *mut ::std::os::raw::c_char,
        end: *mut ::std::os::raw::c_char,
    ) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn update_D_Sym(
        sym: *mut D_Sym,
        st: *mut *mut D_Scope,
        sizeof_D_Sym: ::std::os::raw::c_int,
    ) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn update_additional_D_Sym(
        st: *mut D_Scope,
        sym: *mut D_Sym,
        sizeof_D_Sym: ::std::os::raw::c_int,
    ) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn current_D_Sym(st: *mut D_Scope, sym: *mut D_Sym) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn find_D_Sym_in_Scope(
        st: *mut D_Scope,
        cur: *mut D_Scope,
        name: *mut ::std::os::raw::c_char,
        end: *mut ::std::os::raw::c_char,
    ) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn next_D_Sym_in_Scope(st: *mut *mut D_Scope, sym: *mut *mut D_Sym) -> *mut D_Sym;
}
unsafe extern "C" {
    pub fn print_scope(st: *mut D_Scope);
}
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Parser_User {
    _unused: [u8; 0],
}
pub type d_voidp = *mut ::std::os::raw::c_void;
pub type D_SyntaxErrorFn = ::std::option::Option<unsafe extern "C" fn(arg1: *mut D_Parser)>;
pub type D_AmbiguityFn = ::std::option::Option<
    unsafe extern "C" fn(
        arg1: *mut D_Parser,
        n: ::std::os::raw::c_int,
        v: *mut *mut D_ParseNode,
    ) -> *mut D_ParseNode,
>;
pub type D_FreeNodeFn = ::std::option::Option<unsafe extern "C" fn(d: *mut D_ParseNode)>;
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_Parser {
    pub initial_globals: *mut ::std::os::raw::c_void,
    pub initial_white_space_fn: D_WhiteSpaceFn,
    pub initial_scope: *mut D_Scope,
    pub syntax_error_fn: D_SyntaxErrorFn,
    pub ambiguity_fn: D_AmbiguityFn,
    pub free_node_fn: D_FreeNodeFn,
    pub loc: d_loc_t,
    pub start_state: ::std::os::raw::c_int,
    pub sizeof_user_parse_node: ::std::os::raw::c_int,
    pub save_parse_tree: ::std::os::raw::c_int,
    pub dont_compare_stacks: ::std::os::raw::c_int,
    pub dont_fixup_internal_productions: ::std::os::raw::c_int,
    pub fixup_EBNF_productions: ::std::os::raw::c_int,
    pub dont_merge_epsilon_trees: ::std::os::raw::c_int,
    pub dont_use_height_for_disambiguation: ::std::os::raw::c_int,
    pub dont_use_greediness_for_disambiguation: ::std::os::raw::c_int,
    pub dont_use_deep_priorities_for_disambiguation: ::std::os::raw::c_int,
    pub commit_actions_interval: ::std::os::raw::c_int,
    pub error_recovery: ::std::os::raw::c_int,
    pub partial_parses: ::std::os::raw::c_int,
    pub syntax_errors: ::std::os::raw::c_int,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_Parser"][::std::mem::size_of::<D_Parser>() - 136usize];
    ["Alignment of D_Parser"][::std::mem::align_of::<D_Parser>() - 8usize];
    ["Offset of field: D_Parser::initial_globals"]
        [::std::mem::offset_of!(D_Parser, initial_globals) - 0usize];
    ["Offset of field: D_Parser::initial_white_space_fn"]
        [::std::mem::offset_of!(D_Parser, initial_white_space_fn) - 8usize];
    ["Offset of field: D_Parser::initial_scope"]
        [::std::mem::offset_of!(D_Parser, initial_scope) - 16usize];
    ["Offset of field: D_Parser::syntax_error_fn"]
        [::std::mem::offset_of!(D_Parser, syntax_error_fn) - 24usize];
    ["Offset of field: D_Parser::ambiguity_fn"]
        [::std::mem::offset_of!(D_Parser, ambiguity_fn) - 32usize];
    ["Offset of field: D_Parser::free_node_fn"]
        [::std::mem::offset_of!(D_Parser, free_node_fn) - 40usize];
    ["Offset of field: D_Parser::loc"][::std::mem::offset_of!(D_Parser, loc) - 48usize];
    ["Offset of field: D_Parser::start_state"]
        [::std::mem::offset_of!(D_Parser, start_state) - 80usize];
    ["Offset of field: D_Parser::sizeof_user_parse_node"]
        [::std::mem::offset_of!(D_Parser, sizeof_user_parse_node) - 84usize];
    ["Offset of field: D_Parser::save_parse_tree"]
        [::std::mem::offset_of!(D_Parser, save_parse_tree) - 88usize];
    ["Offset of field: D_Parser::dont_compare_stacks"]
        [::std::mem::offset_of!(D_Parser, dont_compare_stacks) - 92usize];
    ["Offset of field: D_Parser::dont_fixup_internal_productions"]
        [::std::mem::offset_of!(D_Parser, dont_fixup_internal_productions) - 96usize];
    ["Offset of field: D_Parser::fixup_EBNF_productions"]
        [::std::mem::offset_of!(D_Parser, fixup_EBNF_productions) - 100usize];
    ["Offset of field: D_Parser::dont_merge_epsilon_trees"]
        [::std::mem::offset_of!(D_Parser, dont_merge_epsilon_trees) - 104usize];
    ["Offset of field: D_Parser::dont_use_height_for_disambiguation"]
        [::std::mem::offset_of!(D_Parser, dont_use_height_for_disambiguation) - 108usize];
    ["Offset of field: D_Parser::dont_use_greediness_for_disambiguation"]
        [::std::mem::offset_of!(D_Parser, dont_use_greediness_for_disambiguation) - 112usize];
    ["Offset of field: D_Parser::dont_use_deep_priorities_for_disambiguation"]
        [::std::mem::offset_of!(D_Parser, dont_use_deep_priorities_for_disambiguation) - 116usize];
    ["Offset of field: D_Parser::commit_actions_interval"]
        [::std::mem::offset_of!(D_Parser, commit_actions_interval) - 120usize];
    ["Offset of field: D_Parser::error_recovery"]
        [::std::mem::offset_of!(D_Parser, error_recovery) - 124usize];
    ["Offset of field: D_Parser::partial_parses"]
        [::std::mem::offset_of!(D_Parser, partial_parses) - 128usize];
    ["Offset of field: D_Parser::syntax_errors"]
        [::std::mem::offset_of!(D_Parser, syntax_errors) - 132usize];
};
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct D_ParseNode {
    pub symbol: ::std::os::raw::c_int,
    pub start_loc: d_loc_t,
    pub end: *mut ::std::os::raw::c_char,
    pub end_skip: *mut ::std::os::raw::c_char,
    pub scope: *mut D_Scope,
    pub user: d_voidp,
}
#[allow(clippy::unnecessary_operation, clippy::identity_op)]
const _: () = {
    ["Size of D_ParseNode"][::std::mem::size_of::<D_ParseNode>() - 72usize];
    ["Alignment of D_ParseNode"][::std::mem::align_of::<D_ParseNode>() - 8usize];
    ["Offset of field: D_ParseNode::symbol"][::std::mem::offset_of!(D_ParseNode, symbol) - 0usize];
    ["Offset of field: D_ParseNode::start_loc"]
        [::std::mem::offset_of!(D_ParseNode, start_loc) - 8usize];
    ["Offset of field: D_ParseNode::end"][::std::mem::offset_of!(D_ParseNode, end) - 40usize];
    ["Offset of field: D_ParseNode::end_skip"]
        [::std::mem::offset_of!(D_ParseNode, end_skip) - 48usize];
    ["Offset of field: D_ParseNode::scope"][::std::mem::offset_of!(D_ParseNode, scope) - 56usize];
    ["Offset of field: D_ParseNode::user"][::std::mem::offset_of!(D_ParseNode, user) - 64usize];
};
unsafe extern "C" {
    pub fn new_D_Parser(
        t: *mut D_ParserTables,
        sizeof_ParseNode_User: ::std::os::raw::c_int,
    ) -> *mut D_Parser;
}
unsafe extern "C" {
    pub fn free_D_Parser(p: *mut D_Parser);
}
unsafe extern "C" {
    pub fn dparse(
        p: *mut D_Parser,
        buf: *mut ::std::os::raw::c_char,
        buf_len: ::std::os::raw::c_int,
    ) -> *mut D_ParseNode;
}
unsafe extern "C" {
    pub fn free_D_ParseNode(p: *mut D_Parser, pn: *mut D_ParseNode);
}
unsafe extern "C" {
    pub fn free_D_ParseTreeBelow(p: *mut D_Parser, pn: *mut D_ParseNode);
}
unsafe extern "C" {
    pub fn d_get_number_of_children(pn: *mut D_ParseNode) -> ::std::os::raw::c_int;
}
unsafe extern "C" {
    pub fn d_get_child(pn: *mut D_ParseNode, child: ::std::os::raw::c_int) -> *mut D_ParseNode;
}
unsafe extern "C" {
    pub fn d_find_in_tree(pn: *mut D_ParseNode, symbol: ::std::os::raw::c_int) -> *mut D_ParseNode;
}
unsafe extern "C" {
    pub fn d_ws_before(p: *mut D_Parser, pn: *mut D_ParseNode) -> *mut ::std::os::raw::c_char;
}
unsafe extern "C" {
    pub fn d_ws_after(p: *mut D_Parser, pn: *mut D_ParseNode) -> *mut ::std::os::raw::c_char;
}
unsafe extern "C" {
    pub fn d_pass(p: *mut D_Parser, pn: *mut D_ParseNode, pass_number: ::std::os::raw::c_int);
}
unsafe extern "C" {
    pub fn resolve_amb_greedy(
        dp: *mut D_Parser,
        n: ::std::os::raw::c_int,
        v: *mut *mut D_ParseNode,
    ) -> ::std::os::raw::c_int;
}
unsafe extern "C" {
    pub fn d_dup_pathname_str(str_: *const ::std::os::raw::c_char) -> *mut ::std::os::raw::c_char;
}
