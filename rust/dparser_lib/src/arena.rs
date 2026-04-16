//! `arena.rs`
//! A fast, index-based arena allocator structured similarly to DParser's internal freelists.
//! It allows Safe Rust to manage GLR graph cycles effectively using ID indexing.

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct NodeId(pub usize);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct SNodeId(pub usize);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct ZNodeId(pub usize);

pub struct Arena<T> {
    data: Vec<Option<T>>,
    freelist: Vec<usize>,
}

impl<T> Arena<T> {
    pub fn new() -> Self {
        Self::with_capacity(1024)
    }

    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            data: Vec::with_capacity(capacity),
            freelist: Vec::new(),
        }
    }

    pub fn alloc(&mut self, value: T) -> usize {
        if let Some(idx) = self.freelist.pop() {
            self.data[idx] = Some(value);
            idx
        } else {
            let idx = self.data.len();
            self.data.push(Some(value));
            idx
        }
    }

    pub fn free(&mut self, idx: usize) {
        if idx < self.data.len() && self.data[idx].is_some() {
            self.data[idx] = None;
            self.freelist.push(idx);
        }
    }

    pub fn get(&self, idx: usize) -> Option<&T> {
        self.data.get(idx)?.as_ref()
    }

    pub fn get_mut(&mut self, idx: usize) -> Option<&mut T> {
        self.data.get_mut(idx)?.as_mut()
    }

    pub fn iter(&self) -> impl Iterator<Item = (usize, &T)> {
        self.data
            .iter()
            .enumerate()
            .filter_map(|(i, slot)| slot.as_ref().map(|v| (i, v)))
    }
}
