use futures::channel::mpsc::{self, Sender, UnboundedReceiver};
use futures::future::{AbortHandle, Abortable, OptionFuture};
use futures::{Future, SinkExt, StreamExt};
use rustler::env::SavedTerm;
use rustler::types::map;
use rustler::{Atom, Binary, Encoder, Env, ListIterator, LocalPid, NifResult, OwnedBinary, Term};
use rustler::{MapIterator, NifMap, NifUnitEnum, OwnedEnv, ResourceArc};
use std::borrow::BorrowMut;
use std::convert::Infallible;
use std::io::Write;
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, ThreadId};
use std::time::Duration;

use crate::atoms;
use crate::client::ClientResource;
use crate::utils::{maybe_timeout, DecodeOrRaise};

const DEFAULT_READ_LENGTH: usize = 8 * 1024 * 1024;

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

#[derive(NifUnitEnum, Debug)]
enum ErrorCode {
    Cancelled,
    Request,
    Redirect,
    Connect,
    Timeout,
    Body,
    Unknown,
}

#[derive(NifMap, Debug)]
struct Error {
    code: ErrorCode,
    reason: String,
}

impl Error {
    fn cancelled(reason: impl Into<String>) -> Error {
        Error {
            code: ErrorCode::Cancelled,
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

/// To store an erlang term we need an `OwnedEnv` too.
struct CallerRef {
    env: OwnedEnv,
    ref_: SavedTerm,
}

impl<'a> Into<CallerRef> for Term<'a> {
    fn into(self) -> CallerRef {
        let env = OwnedEnv::new();
        CallerRef {
            ref_: env.save(self),
            env,
        }
    }
}

impl Encoder for CallerRef {
    fn encode<'a>(&self, dest: Env<'a>) -> Term<'a> {
        self.env.run(|env| self.ref_.load(env).in_env(dest))
    }
}

/// Sent when erlang is streaming the request body
enum SendCmd {
    Send(Vec<u8>),
    FinishSend,
}

/// Options for reading a chunk of the response body
struct ReadOpts {
    length: usize,
    period: Option<Duration>,
}

enum IsFin {
    Fin,
    NoFin,
}

/// Helper for storing/encoding an HTTP response
struct Resp {
    status: u16,
    headers: Vec<(String, OwnedBinary)>,
    body: Option<OwnedBinary>,
}

impl Resp {
    fn encode(self, env: Env) -> Term {
        let headers1: Vec<_> = self
            .headers
            .into_iter()
            .map(|(k, v)| (k, v.release(env)))
            .collect();
        let mut map = map::map_new(env);
        map = map
            .map_put(atoms::status().encode(env), self.status.encode(env))
            .unwrap();
        map = map
            .map_put(atoms::headers().encode(env), headers1.encode(env))
            .unwrap();
        if let Some(body) = self.body {
            map = map
                .map_put(atoms::body().encode(env), body.release(env).encode(env))
                .unwrap();
        }
        map.encode(env)
    }
}

struct Request {
    caller_ref: Option<CallerRef>,
    caller_pid: LocalPid,
    initial_thread: ThreadId,
    /// An indicator for whether the future was dropped. This doesn't strictly
    /// need to be an atomic since we only access it from `initial_thread`.
    dropped_on_initial_thread: Arc<AtomicBool>,
    /// The channels we use to feed the request body to `reqwest`: The other end
    /// of the `Sender` is converted to a Stream and given to `reqwest`. We get
    /// new data from erlang on the receiver and feed it to the sender. This
    /// allows us to provide backpressure by replying to erlang after each chunk
    /// is successfully `fed`.
    req_body_channels: Option<(
        Sender<Result<Vec<u8>, Infallible>>,
        UnboundedReceiver<SendCmd>,
    )>,
    resp_stream_rx: Option<UnboundedReceiver<ReadOpts>>,
}

impl Request {
    /// Creating an `OwnedEnv` has a (small) cost. When it's time to send the
    /// final message, we exploit the fact that `CallerRef` has an `OwnedEnv`
    /// that will no longer be needed. `take`ing the `CallerRef` signals to the
    /// `Drop` implementation that a final reply has been sent and there is no
    /// need to send a `cancelled` message.
    fn reply_final<F>(&mut self, f: F)
    where
        F: for<'a> FnOnce(Env<'a>, Term<'a>) -> Term<'a>,
    {
        let CallerRef { mut env, ref_ } = self.caller_ref.take().unwrap();
        env.send_and_clear(&self.caller_pid, |env| f(env, ref_.load(env)))
    }
    fn reply_error(&mut self, e: Error) {
        self.reply_final(|env, ref_| {
            (atoms::erqwest_response(), ref_, atoms::error(), e).encode(env)
        })
    }
    fn reply_none(&mut self) {
        self.caller_ref.take().unwrap();
    }
    async fn run(mut self, builder: reqwest::RequestBuilder) {
        let resp = builder.send();
        tokio::pin!(resp);
        let res = if let Some((mut tx, rx)) = self.req_body_channels.take() {
            match self.stream_req(&mut resp, &mut tx, rx).await {
                Some(Ok(res)) => res,
                Some(Err(e)) => {
                    // drop the request future before the tx, since
                    // closing the tx means "complete the request".
                    drop(resp);
                    drop(tx);
                    self.reply_error(e.into());
                    return;
                }
                None => {
                    // drop the request future before the tx, since
                    // closing the tx means "complete the request".
                    drop(resp);
                    drop(tx);
                    // the client is not waiting for a reply (eg. has
                    // cancelled), so we don't reply
                    self.reply_none();
                    return;
                }
            }
        } else {
            match resp.await {
                Ok(res) => res,
                Err(e) => {
                    self.reply_error(e.into());
                    return;
                }
            }
        };
        let status = res.status().as_u16();
        let mut headers = Vec::with_capacity(res.headers().len());
        for (k, v) in res.headers().iter() {
            let mut v1 = OwnedBinary::new(v.as_bytes().len()).unwrap();
            v1.as_mut_slice().write_all(v.as_bytes()).unwrap();
            headers.push((k.as_str().into(), v1))
        }
        if let Some(rx) = self.resp_stream_rx.take() {
            let partial_resp = Resp {
                status,
                headers,
                body: None,
            };
            self.stream_resp(res, rx, partial_resp).await;
        } else {
            match res.bytes().await {
                Ok(bytes) => {
                    let mut body = OwnedBinary::new(bytes.len()).unwrap();
                    body.as_mut_slice().write_all(&bytes).unwrap();
                    let resp = Resp {
                        status,
                        headers,
                        body: Some(body),
                    };
                    self.reply_final(|env, ref_| {
                        (
                            atoms::erqwest_response(),
                            ref_,
                            atoms::reply(),
                            resp.encode(env),
                        )
                            .encode(env)
                    });
                }
                Err(e) => self.reply_error(e.into()),
            }
        }
    }
    /// Stream the request body and wait for the response. These two things need
    /// to be combined, since a response can come at any time (even before the
    /// request body is complete). Return values: `Ok(reply | error)` => send a
    /// reply message, `None` => the stream was cancelled, end without replying.
    async fn stream_req(
        &mut self,
        mut resp: &mut Pin<&mut impl Future<Output = reqwest::Result<reqwest::Response>>>,
        tx: &mut Sender<Result<Vec<u8>, Infallible>>,
        mut rx: UnboundedReceiver<SendCmd>,
    ) -> Option<reqwest::Result<reqwest::Response>> {
        let env = OwnedEnv::new();
        let term_next = env.run(|e| {
            env.save(
                (
                    atoms::erqwest_response(),
                    &self.caller_ref.as_ref().unwrap(),
                    atoms::next(),
                )
                    .encode(e),
            )
        });
        let mut fin = false;
        loop {
            tokio::select! {
                next = rx.next(), if !fin =>
                    match next {
                        Some(SendCmd::Send(data)) => {
                            let feed = tx.feed(Ok(data));
                            tokio::select! {
                                Ok(()) = feed =>
                                    env.run(|env| env.send(&self.caller_pid, term_next.load(env))),
                                // the caller is waiting for a response so we can reply immediately
                                res = &mut resp => return Some(res)
                            }
                        },
                        Some(SendCmd::FinishSend) => {
                            tx.close_channel();
                            // now we just wait for the response
                            fin = true;
                        },
                        None => {
                            // the caller has not asked for a response and will
                            // never be able to, exit without replying
                            return None
                        }
                },
                res = &mut resp => {
                    if fin {
                        // the caller is waiting for a response so reply immediately
                        return Some(res)
                    } else {
                        // the caller is not expecting a response yet so wait for the next command
                        if rx.next().await.is_none() {
                            // the caller has not asked for a response and never
                            // can, so we exit without replying
                            return None
                        } else {
                            return Some(res)
                        }
                    }
                }
            }
        }
    }
    /// Stream the response body. This is always called last, so we are
    /// responsible for sending the final message (reply, error, or nothing if
    /// streaming was cancelled).
    async fn stream_resp(
        &mut self,
        mut resp: reqwest::Response,
        mut rx: UnboundedReceiver<ReadOpts>,
        partial_resp: Resp,
    ) {
        let mut env = OwnedEnv::new();
        env.run(|env| {
            env.send(
                &self.caller_pid,
                (
                    atoms::erqwest_response(),
                    self.caller_ref.as_ref().unwrap(),
                    atoms::reply(),
                    partial_resp.encode(env),
                )
                    .encode(env),
            )
        });
        let mut buf = Vec::new();
        loop {
            match rx.next().await {
                Some(opts) => {
                    buf.clear();
                    // TODO: use stream instead of resp directly
                    match stream_response_chunk(&mut resp, opts, &mut buf).await {
                        Ok(res) => {
                            let mut bin = OwnedBinary::new(buf.len()).unwrap();
                            bin.as_mut_slice().write_all(&buf).unwrap();
                            match res {
                                IsFin::NoFin => {
                                    env.run(|env| {
                                        env.send(
                                            &self.caller_pid,
                                            (
                                                atoms::erqwest_response(),
                                                &self.caller_ref.as_ref().unwrap(),
                                                atoms::chunk(),
                                                Binary::from_owned(bin, env),
                                            )
                                                .encode(env),
                                        )
                                    });
                                    env.clear();
                                }
                                IsFin::Fin => {
                                    // Before we send the reply, drop the rx to make
                                    // sure that further calls to `read` fail
                                    drop(rx);
                                    self.reply_final(|env, ref_| {
                                        (
                                            atoms::erqwest_response(),
                                            ref_,
                                            atoms::fin(),
                                            Binary::from_owned(bin, env),
                                        )
                                            .encode(env)
                                    });
                                    return;
                                }
                            }
                        }
                        Err(e) => {
                            // Before we send the reply, drop the rx to make
                            // sure that further calls to `read` fail
                            drop(rx);
                            self.reply_error(e.into());
                            return;
                        }
                    }
                }
                None => {
                    // The caller is not awaiting a response and never will
                    self.reply_none();
                    return;
                }
            }
        }
    }
}

impl Drop for Request {
    fn drop(&mut self) {
        if self.caller_ref.is_some() {
            if thread::current().id() == self.initial_thread {
                // We are still on the initial thread, which means the future
                // was not spawned. We can't send a message from this thread
                // (managed by the VM) so we set this flag and
                // `req` returns BadArg.
                self.dropped_on_initial_thread
                    .borrow_mut()
                    .store(true, Ordering::Relaxed);
            } else {
                self.reply_error(Error::cancelled("future dropped"));
            }
        }
    }
}

async fn stream_response_chunk(
    response: &mut reqwest::Response,
    opts: ReadOpts,
    buf: &mut Vec<u8>, // passed in so we can reuse the memory allocation between chunks
) -> Result<IsFin, Error> {
    let timeout = OptionFuture::from(opts.period.map(tokio::time::sleep));
    tokio::pin!(timeout);
    loop {
        tokio::select! {
            // TODO: is this cancellation safe? maybe safer to use a stream which is guaranteed?
            res = response.chunk() => match res {
                Ok(Some(chunk)) => {
                    buf.extend_from_slice(&chunk);
                    if buf.len() >= opts.length {
                        return Ok(IsFin::NoFin);
                    }
                }
                Ok(None) => return Ok(IsFin::Fin),
                Err(e) => return Err(e.into()),
            },
            Some(()) = &mut timeout => return Ok(IsFin::NoFin)
        }
    }
}

pub struct ReqHandle {
    abort_handle: AbortHandle,
    req_body_tx: Option<mpsc::UnboundedSender<SendCmd>>,
    resp_stream_tx: Option<mpsc::UnboundedSender<ReadOpts>>,
}

/// Helper for decoding the `body` opt
#[derive(NifUnitEnum, PartialEq)]
enum StreamBody {
    Stream,
}

/// Helper for decoding the `response_body` opt
#[derive(NifUnitEnum)]
enum ResponseBody {
    Stream,
    Complete,
}

#[rustler::nif]
fn req(
    resource: ResourceArc<ClientResource>,
    pid: LocalPid,
    caller_ref: Term,
    opts: Term,
) -> NifResult<ResourceArc<ReqHandle>> {
    let ReqBase { url, method } = opts.decode_or_raise()?;
    // returns BadArg if the client was already closed with close_client
    let client = resource
        .client
        .read()
        .unwrap()
        .as_ref()
        .ok_or(rustler::Error::BadArg)?
        .clone();
    let mut req_builder = client.request(method.into(), url);
    let mut req_body_tx = None;
    let mut req_body_channels = None;
    let mut resp_stream_tx = None;
    let mut resp_stream_rx = None;
    for (k, v) in opts.decode::<MapIterator>()? {
        let k: Atom = k.decode()?;
        if k == atoms::headers() {
            for h in v.decode::<ListIterator>()? {
                let (k, v): (&str, &str) = h.decode_or_raise()?;
                req_builder = req_builder.header(k, v);
            }
        } else if k == atoms::body() {
            if let Ok(body) = v.decode_as_binary() {
                req_builder = req_builder.body(body.as_slice().to_owned());
            } else {
                v.decode_or_raise::<StreamBody>()?;
                let (tx, rx) = mpsc::channel::<Result<Vec<u8>, Infallible>>(0);
                let (body_tx, body_rx0) = mpsc::unbounded();
                req_builder = req_builder.body(reqwest::Body::wrap_stream(rx));
                req_body_tx = Some(body_tx);
                req_body_channels = Some((tx, body_rx0));
            }
        } else if k == atoms::response_body() {
            match v.decode_or_raise()? {
                ResponseBody::Complete => (),
                ResponseBody::Stream => {
                    let (tx, rx) = mpsc::unbounded();
                    resp_stream_tx = Some(tx);
                    resp_stream_rx = Some(rx);
                }
            }
        } else if k == atoms::timeout() {
            if let Some(timeout) = maybe_timeout(v)? {
                req_builder = req_builder.timeout(timeout);
            }
        } else if k != atoms::method() && k != atoms::url() {
            return Err(rustler::Error::RaiseTerm(Box::new((atoms::bad_opt(), k))));
        }
    }
    let req = Request {
        caller_ref: Some(caller_ref.into()),
        caller_pid: pid,
        dropped_on_initial_thread: Arc::new(AtomicBool::new(false)),
        req_body_channels,
        resp_stream_rx,
        initial_thread: thread::current().id(),
    };
    // This allows us to detect if the future was immediately dropped (ie. not
    // sent to another thread), which indicates that the Runtime is shutting
    // down or has shut down.
    let dropped_on_initial_thread = req.dropped_on_initial_thread.clone();
    let fut = req.run(req_builder);
    let (abort_handle, abort_registration) = AbortHandle::new_pair();
    resource
        .runtime
        .spawn(Abortable::new(fut, abort_registration));
    if dropped_on_initial_thread.load(Ordering::Relaxed) {
        Err(rustler::Error::RaiseAtom("bad_runtime"))
    } else {
        Ok(ResourceArc::new(ReqHandle {
            abort_handle,
            req_body_tx,
            resp_stream_tx,
        }))
    }
}

/// Intended to be used by `erqwest_async`, and causes the future to be dropped
/// ASAP.
#[rustler::nif]
fn cancel(req_handle: ResourceArc<ReqHandle>) -> NifResult<Atom> {
    req_handle.abort_handle.abort();
    Ok(atoms::ok())
}

/// Intended to be used by `erqwest` (the sync interface). It is unable to cause
/// an immediate interruption (eg. if the future is waiting for a data from the
/// server), but that's OK because there is no way for the user to express that
/// through the sync API (apart from killing the process).
#[rustler::nif]
fn cancel_stream(req_handle: ResourceArc<ReqHandle>) -> Atom {
    if let Some(body_tx) = req_handle.req_body_tx.as_ref() {
        body_tx.close_channel();
    }
    if let Some(resp_stream_tx) = req_handle.resp_stream_tx.as_ref() {
        resp_stream_tx.close_channel();
    }
    atoms::ok()
}

/// Stream a chunk of the request body
#[rustler::nif]
fn send<'a>(
    env: Env<'a>,
    req_handle: ResourceArc<ReqHandle>,
    data: Term<'a>,
) -> NifResult<Term<'a>> {
    if let Some(body_tx) = req_handle.req_body_tx.as_ref() {
        let cmd = SendCmd::Send(data.decode_as_binary()?.to_vec());
        if body_tx.unbounded_send(cmd).is_ok() {
            return Ok(atoms::ok().encode(env));
        }
    }
    Err(rustler::Error::BadArg)
}

#[rustler::nif]
fn finish_send(req_handle: ResourceArc<ReqHandle>) -> NifResult<Atom> {
    if let Some(body_tx) = req_handle.req_body_tx.as_ref() {
        if body_tx.unbounded_send(SendCmd::FinishSend).is_ok() {
            body_tx.close_channel();
            return Ok(atoms::ok());
        }
    }
    Err(rustler::Error::BadArg)
}

/// Stream a chunk of the response body
#[rustler::nif]
fn read<'a>(
    env: Env<'a>,
    req_handle: ResourceArc<ReqHandle>,
    opts_or_cancel: Term,
) -> NifResult<Term<'a>> {
    let mut period = None;
    let mut length = DEFAULT_READ_LENGTH;
    for (k, v) in opts_or_cancel.decode::<MapIterator>()? {
        let k: Atom = k.decode_or_raise()?;
        if k == atoms::length() {
            length = v.decode_or_raise()?;
        } else if k == atoms::period() {
            period = maybe_timeout(v)?;
        } else {
            return Err(rustler::Error::RaiseTerm(Box::new((atoms::bad_opt(), k))));
        }
    }
    let opts = ReadOpts { length, period };
    if let Some(resp_stream_tx) = req_handle.resp_stream_tx.as_ref() {
        if resp_stream_tx.unbounded_send(opts).is_ok() {
            return Ok(atoms::ok().encode(env));
        }
    }
    Err(rustler::Error::BadArg)
}
