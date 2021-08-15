use futures::future::{AbortHandle, Abortable};
use rustler::env::SavedTerm;
use rustler::types::map;
use rustler::{Atom, Binary, Encoder, Env, ListIterator, LocalPid, NifResult, OwnedBinary, Term};
use rustler::{NifMap, NifUnitEnum, OwnedEnv, ResourceArc};
use std::borrow::BorrowMut;
use std::io::Write;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, ThreadId};

use crate::atoms;
use crate::client::ClientResource;
use crate::utils::{DecodeOrRaise, maybe_timeout};

#[derive(NifUnitEnum, Clone, Copy, Debug)]
enum Method {
    Options,
    Get,
    Post,
    Put,
    Delete,
    Head,
    Trace,
    Connect,
    Patch,
}

impl From<Method> for reqwest::Method {
    fn from(method: Method) -> Self {
        use Method::*;
        match method {
            Options => reqwest::Method::OPTIONS,
            Get => reqwest::Method::GET,
            Post => reqwest::Method::POST,
            Put => reqwest::Method::PUT,
            Delete => reqwest::Method::DELETE,
            Head => reqwest::Method::HEAD,
            Trace => reqwest::Method::TRACE,
            Connect => reqwest::Method::CONNECT,
            Patch => reqwest::Method::PATCH,
        }
    }
}

#[derive(NifMap)]
struct ReqBase {
    url: String,
    method: Method,
}

#[derive(NifUnitEnum)]
enum ErrorCode {
    Cancelled,
    Request,
    Redirect,
    Connect,
    Timeout,
    Body,
    Unknown,
}

#[derive(NifMap)]
struct Error {
    code: ErrorCode,
    reason: String,
}

impl Error {
    fn unknown(reason: impl Into<String>) -> Error {
        Error {
            code: ErrorCode::Unknown,
            reason: reason.into(),
        }
    }
}

impl From<reqwest::Error> for Error {
    fn from(e: reqwest::Error) -> Error {
        use ErrorCode::*;
        let code = if e.is_timeout() {
            Timeout
        } else if e.is_redirect() {
            Redirect
        } else if e.is_connect() {
            Connect
        } else if e.is_request() {
            Request
        } else if e.is_body() {
            Body
        } else {
            Unknown
        };
        let reason = e.to_string();
        Error { code, reason }
    }
}

struct ErqwestResponse {
    env: Option<OwnedEnv>,
    caller_ref: SavedTerm,
    caller_pid: LocalPid,
    initial_thread: ThreadId,
    dropped_on_initial_thread: Arc<AtomicBool>,
}

impl ErqwestResponse {
    pub fn new(caller_ref: Term, caller_pid: LocalPid) -> ErqwestResponse {
        let env = OwnedEnv::new();
        let caller_ref = env.save(caller_ref);
        ErqwestResponse {
            env: Some(env),
            caller_ref,
            caller_pid,
            initial_thread: thread::current().id(),
            dropped_on_initial_thread: Arc::new(AtomicBool::new(false)),
        }
    }
    fn send(&mut self, res: Result<(u16, Vec<(String, OwnedBinary)>, OwnedBinary), Error>) {
        self.env
            .take()
            .unwrap()
            .send_and_clear(&self.caller_pid, |env| {
                let res = res.and_then(|r| {
                    encode_resp(env, r).map_err(|_| Error::unknown("failed encoding result"))
                });
                let res = match res {
                    Ok(term) => (atoms::ok(), term).encode(env),
                    Err(e) => env.error_tuple(e),
                };
                let caller_ref = self.caller_ref.load(env);
                (atoms::erqwest_response(), caller_ref, res).encode(env)
            });
    }
}

impl Drop for ErqwestResponse {
    fn drop(&mut self) {
        if self.env.is_some() {
            if thread::current().id() == self.initial_thread {
                // We are still on the initial thread, which means the future
                // was not spawned. We can't send a message from this thread
                // (managed by the VM) so we set this flag and
                // `req_async_internal` returns BadArg.
                self.dropped_on_initial_thread
                    .borrow_mut()
                    .store(true, Ordering::Relaxed);
            } else {
                self.send(Err(Error {
                    code: ErrorCode::Cancelled,
                    reason: "future dropped".into(),
                }));
            }
        }
    }
}

pub struct AbortResource(AbortHandle);

#[rustler::nif]
fn req_async_internal(
    env: Env,
    resource: ResourceArc<ClientResource>,
    pid: LocalPid,
    caller_ref: Term,
    req: Term,
) -> NifResult<ResourceArc<AbortResource>> {
    let ReqBase { url, method } = req.decode_or_raise()?;
    // returns BadArg if the client was already closed with close_client
    let client = resource
        .client
        .read()
        .unwrap()
        .as_ref()
        .ok_or(rustler::Error::BadArg)?
        .clone();
    let mut req_builder = client.request(method.into(), url);
    if let Ok(term) = req.map_get(atoms::headers().encode(env)) {
        for h in term.decode::<ListIterator>()? {
            let (k, v): (&str, &str) = h.decode_or_raise()?;
            req_builder = req_builder.header(k, v);
        }
    };
    if let Ok(term) = req.map_get(atoms::body().encode(env)) {
        req_builder = req_builder.body(term.decode::<Binary>()?.as_slice().to_owned());
    };
    if let Ok(term) = req.map_get(atoms::timeout().encode(env)) {
        if let Some(timeout) = maybe_timeout(term)? {
            req_builder = req_builder.timeout(timeout);
        }
    };
    let mut response = ErqwestResponse::new(caller_ref, pid);
    // This allows us to detect if the future was immediately dropped (ie. not
    // sent to another thread), which indicates that the Runtime is shutting
    // down or has shut down.
    let dropped_on_initial_thread = response.dropped_on_initial_thread.clone();
    let fut = async move {
        let resp = do_req(req_builder).await;
        response.send(resp);
    };
    let (abort_handle, abort_registration) = AbortHandle::new_pair();
    resource
        .runtime
        .spawn(Abortable::new(fut, abort_registration));
    if dropped_on_initial_thread.load(Ordering::Relaxed) {
        Err(rustler::Error::RaiseAtom("bad_runtime"))
    } else {
        Ok(ResourceArc::new(AbortResource(abort_handle)))
    }
}

async fn do_req(
    req: reqwest::RequestBuilder,
) -> Result<(u16, Vec<(String, OwnedBinary)>, OwnedBinary), Error> {
    let resp = req.send().await?;
    let status = resp.status().as_u16();
    let mut headers = Vec::with_capacity(resp.headers().len());
    for (k, v) in resp.headers().iter() {
        let mut v1 = OwnedBinary::new(v.as_bytes().len()).unwrap();
        v1.as_mut_slice().write_all(v.as_bytes()).unwrap();
        headers.push((k.as_str().into(), v1))
    }
    let bytes = resp.bytes().await?;
    let mut body = OwnedBinary::new(bytes.len()).unwrap();
    body.as_mut_slice().write_all(&bytes).unwrap();
    Ok((status, headers, body))
}

fn encode_resp(
    env: Env,
    (status, headers, body): (u16, Vec<(String, OwnedBinary)>, OwnedBinary),
) -> NifResult<Term> {
    let headers1: Vec<_> = headers
        .into_iter()
        .map(|(k, v)| (k, v.release(env)))
        .collect();
    let mut map = map::map_new(env);
    map = map.map_put(atoms::status().encode(env), status.encode(env))?;
    map = map.map_put(atoms::headers().encode(env), headers1.encode(env))?;
    map = map.map_put(atoms::body().encode(env), body.release(env).encode(env))?;
    Ok(map.encode(env))
}

#[rustler::nif]
fn cancel(abort_handle: ResourceArc<AbortResource>) -> NifResult<Atom> {
    abort_handle.0.abort();
    Ok(atoms::ok())
}
