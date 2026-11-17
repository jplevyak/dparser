//! `state.rs`
//! Threaded state (`${state}`): immutable, path-specific values interned by
//! the parser, so that comparing states is comparing [`StateId`]s.

use std::any::Any;
use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::hash::{Hash, Hasher};

/// A threaded state value, interned in [`States`].  `StateId::NONE` (the
/// default) means no state.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct StateId(pub u32);

impl StateId {
    pub const NONE: StateId = StateId(0);

    pub fn is_none(self) -> bool {
        self == StateId::NONE
    }
}

trait StateValue: Any {
    fn eq_dyn(&self, other: &dyn StateValue) -> bool;
    fn as_any(&self) -> &dyn Any;
}

impl<T: Any + Eq> StateValue for T {
    fn eq_dyn(&self, other: &dyn StateValue) -> bool {
        other.as_any().downcast_ref::<T>() == Some(self)
    }
    fn as_any(&self) -> &dyn Any {
        self
    }
}

/// The interned state values of a parser.  Values of any `Eq + Hash` type
/// can be interned; equal values get the same [`StateId`].  Values live
/// until the parser is dropped.
#[derive(Default)]
pub struct States {
    values: Vec<Box<dyn StateValue>>,
    index: HashMap<u64, Vec<u32>>,
}

impl States {
    pub fn new() -> Self {
        Self::default()
    }

    /// The id of `value`, interning it if it is new.
    pub fn intern<T: Any + Eq + Hash>(&mut self, value: T) -> StateId {
        let mut h = DefaultHasher::new();
        std::any::TypeId::of::<T>().hash(&mut h);
        value.hash(&mut h);
        let bucket = self.index.entry(h.finish()).or_default();
        for &i in bucket.iter() {
            if self.values[i as usize].eq_dyn(&value) {
                return StateId(i + 1);
            }
        }
        self.values.push(Box::new(value));
        let i = (self.values.len() - 1) as u32;
        bucket.push(i);
        StateId(i + 1)
    }

    /// The value of `id`, if it is a `T`.
    pub fn get<T: Any>(&self, id: StateId) -> Option<&T> {
        if id.is_none() {
            return None;
        }
        self.values.get(id.0 as usize - 1)?.as_any().downcast_ref::<T>()
    }

    /// The number of distinct values interned.
    pub fn len(&self) -> usize {
        self.values.len()
    }

    pub fn is_empty(&self) -> bool {
        self.values.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn interning() {
        let mut s = States::new();
        let a = s.intern(3i32);
        let b = s.intern(String::from("x"));
        assert_eq!(s.intern(3i32), a);
        assert_eq!(s.intern(String::from("x")), b);
        assert_ne!(s.intern(3u8), a, "values of different types differ");
        assert_eq!(s.get::<i32>(a), Some(&3));
        assert_eq!(s.get::<String>(a), None);
        assert_eq!(s.get::<i32>(StateId::NONE), None);
        assert_eq!(s.len(), 3);
    }
}
