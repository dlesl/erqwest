use std::time::Duration;

use rustler::{NifResult, NifUnitEnum, NifUntaggedEnum, Term};

#[derive(NifUnitEnum)]
enum Infinity {
    Infinity,
}

#[derive(NifUntaggedEnum)]
enum Timeout {
    Infinity(Infinity),
    Timeout(u64),
}

pub fn maybe_timeout(t: Term) -> NifResult<Option<Duration>> {
    match t.decode()? {
        Timeout::Infinity(_) => Ok(None),
        Timeout::Timeout(ms) => Ok(Some(Duration::from_millis(ms))),
    }
}
