use std::time::Duration;

use rustler::{Decoder, NifResult, NifUnitEnum, NifUntaggedEnum, Term};

// Decoding enums using the code generated by `rustler_codegen` in some cases
// (such as unit enums) returns an atom instead of raising an exception. This
// adaptor fixes that.
pub trait DecodeOrRaise<'a>: Sized + 'a {
    fn decode_or_raise<T: Decoder<'a>>(self) -> NifResult<T>;
}

impl<'a> DecodeOrRaise<'a> for Term<'a> {
    fn decode_or_raise<T: Decoder<'a>>(self) -> NifResult<T> {
        use rustler::Error::*;
        match self.decode() {
            Ok(res) => Ok(res),
            Err(e) => Err(match e {
                BadArg => BadArg,
                Atom(s) | RaiseAtom(s) => RaiseAtom(s),
                Term(t) | RaiseTerm(t) => RaiseTerm(t),
            }),
        }
    }
}

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
    match t.decode_or_raise()? {
        Timeout::Infinity(_) => Ok(None),
        Timeout::Timeout(ms) => Ok(Some(Duration::from_millis(ms))),
    }
}
