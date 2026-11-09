# itempool vision

itempool is a small Rust crate for managing a pool of reusable items. It
provides traits, not a container: an implementor keeps its own `Vec<T>` and gets
random removal, unique-set retrieval, and a discard/recycle path. It is aimed at
code that hands out resources — workers, connections, units, game pieces — and
needs to take them back without losing track of them.

## Problem

That pattern is usually reimplemented per project as a vector plus a discard
list. The copies diverge: discarded items are forgotten, set retrieval returns
duplicates, or the pool has no way to return an item at all. A tiny shared trait
keeps the semantics in one place and leaves storage decisions to the caller.

## Principles

- **Traits over containers.** `PoolItem` and `ItemPool<T>` define behaviour;
  the implementor owns the storage and decides what a pool means for its type.
- **Type bounds carry the invariants.** Items are `Hash + Eq + Sync`, which is
  what uniqueness checks and shared use actually require.
- **Recycling is a separate trait.** `RecyclingItemPool<T>` adds a discard pool
  with `discard_one()`, `recycle_discarded()`, and `get_set()`, so types that
  only need removal are not forced to carry discard state.
- **Portable and dependency-light.** The crate works on `wasm32-unknown-unknown`
  and keeps its feature surface minimal.

## Scope

- `PoolItem` trait for items usable in a pool
- `ItemPool<T>` trait with `pool()`, `put()`, `remove_one()`, `remove_many()`,
  and `remove_set()`
- `RecyclingItemPool<T>` trait with `get_discard_pool()`, `discard_one()`,
  `recycle_discarded()`, and `get_set()`
- default method implementations where the trait can supply them
- crates.io packaging, CI, and a Nix flake

## Direction

Not yet documented; the repository has one release (0.1.0) and later commits are
build-infrastructure updates.

## Place in the fleet

`spacepirates` depends on `itempool = "0.1.0"` from its client crate.
