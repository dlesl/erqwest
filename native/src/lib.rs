use rustler::types::map;
use rustler::{Atom, Binary, Encoder, Env, ListIterator, LocalPid, NifResult, OwnedBinary, Term};
use rustler::{NifMap, NifUnitEnum, OwnedEnv, ResourceArc};
use std::thread;
use tokio::runtime::{Handle, Runtime};

mod atoms {
    rustler::atoms! {
        erqwest_response,
        body,
        url,
        code,
        headers,
        method,
        reason,
        ok,
        error
    }
}

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

impl Into<reqwest::Method> for Method {
    fn into(self) -> reqwest::Method {
        use Method::*;
        match self {
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
struct Req {
    url: String,
    method: Method,
}

#[derive(NifMap)]
struct Error {
    code: ErrorCode,
    reason: String,
}

#[derive(NifUnitEnum)]
enum ErrorCode {
    Request,
    Connect,
    Timeout,
    Body,
    Unknown,
}

impl From<&reqwest::Error> for ErrorCode {
    fn from(e: &reqwest::Error) -> ErrorCode {
        use ErrorCode::*;
        if e.is_request() {
            Request
        } else if e.is_connect() {
            Connect
        } else if e.is_timeout() {
            Timeout
        } else if e.is_body() {
            Body
        } else {
            Unknown
        }
    }
}

lazy_static::lazy_static! {
    static ref HANDLE: Handle = {
        let (handle_tx, handle_rx) = std::sync::mpsc::channel();
        thread::spawn(move || {
            let runtime = Runtime::new().unwrap();
            handle_tx.send(runtime.handle().clone()).unwrap();
            runtime.block_on(std::future::pending::<()>());
        });
        handle_rx.recv().unwrap()
    };
}

struct ClientResource(reqwest::Client);

#[rustler::nif]
fn make_client(env: Env) -> ResourceArc<ClientResource> {
    let _ = env;
    ResourceArc::new(ClientResource(reqwest::Client::new()))
}

#[rustler::nif]
fn req_async(
    resource: ResourceArc<ClientResource>,
    pid: LocalPid,
    caller_ref: Term,
    req: Term,
) -> NifResult<Atom> {
    let client = resource.0.clone();
    let mut msg_env = OwnedEnv::new();
    let caller_ref = msg_env.save(caller_ref);
    let env = req.get_env();
    let url: String = req.map_get(atoms::url().encode(env))?.decode()?;
    let method: Method = req.map_get(atoms::method().encode(env))?.decode()?;
    let mut req_builder = client.request(method.into(), url);
    match req.map_get(atoms::headers().encode(env)) {
        Ok(term) => {
            for h in term.decode::<ListIterator>()? {
                let (k, v): (&str, &str) = h.decode()?;
                req_builder = req_builder.header(k, v);
            }
        }
        Err(_) => (),
    };
    match req.map_get(atoms::body().encode(env)) {
        Ok(term) => {
            req_builder = req_builder.body(term.decode::<Binary>()?.as_slice().to_owned());
        }
        Err(_) => (),
    };
    HANDLE.spawn(async move {
        let resp = do_req(req_builder).await;
        msg_env.send_and_clear(&pid, |env| {
            let resp = match resp {
                Ok((code, headers, body)) => {
                    let headers1: Vec<_> = headers
                        .into_iter()
                        .map(|(k, v)| (k, v.release(env)))
                        .collect();
                    let mut map = map::map_new(env);
                    map = map
                        .map_put(atoms::code().encode(env), code.encode(env))
                        .unwrap();
                    map = map
                        .map_put(atoms::headers().encode(env), headers1.encode(env))
                        .unwrap();
                    map = map
                        .map_put(atoms::body().encode(env), body.release(env).encode(env))
                        .unwrap();
                    (atoms::ok(), map).encode(env)
                }
                Err(e) => (
                    atoms::error(),
                    Error {
                        code: (&e).into(),
                        reason: e.to_string(),
                    },
                )
                    .encode(env),
            };
            let caller_ref = caller_ref.load(env);
            (atoms::erqwest_response(), caller_ref, resp).encode(env)
        });
    });
    Ok(atoms::ok())
}

async fn do_req(
    req: reqwest::RequestBuilder,
) -> reqwest::Result<(u16, Vec<(String, OwnedBinary)>, OwnedBinary)> {
    let resp = req.send().await?;
    let code = resp.status().as_u16();
    let headers = resp
        .headers()
        .iter()
        .map(|(k, v)| {
            let mut v1 = OwnedBinary::new(v.as_bytes().len()).unwrap();
            v1.as_mut_slice().copy_from_slice(v.as_bytes());
            (k.as_str().into(), v1)
        })
        .collect();
    let bytes = resp.bytes().await?;
    let mut body = OwnedBinary::new(bytes.len()).unwrap();
    body.as_mut_slice().copy_from_slice(&bytes);
    Ok((code, headers, body))
}

fn load(env: Env, _info: Term) -> bool {
    lazy_static::initialize(&HANDLE);
    rustler::resource!(ClientResource, env);
    true
}

rustler::init!("erqwest", [make_client, req_async], load = load);
