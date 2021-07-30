use reqwest::{Certificate, Identity};
use rustler::types::map;
use rustler::{Atom, Binary, Encoder, Env, ListIterator, LocalPid, NifResult, OwnedBinary, Term};
use rustler::{NifMap, NifUnitEnum, OwnedEnv, ResourceArc};
use std::io::Write;
use std::sync::RwLock;
use std::thread;
use std::time::Duration;
use tokio::runtime::{Handle, Runtime};

mod atoms {
    rustler::atoms! {
        additional_root_certs,
        body,
        status,
        erqwest_response,
        error,
        follow_redirects,
        headers,
        identity,
        method,
        ok,
        reason,
        timeout,
        url,
        use_built_in_root_certs
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

#[derive(NifUnitEnum)]
enum ErrorCode {
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

struct ClientResource(RwLock<Option<reqwest::Client>>);

#[rustler::nif]
fn make_client(env: Env, opts: Term) -> NifResult<ResourceArc<ClientResource>> {
    let _ = env;
    if !opts.is_map() {
        return Err(rustler::Error::BadArg);
    }
    let mut builder = reqwest::ClientBuilder::new();
    match opts.map_get(atoms::identity().encode(env)) {
        Ok(term) => {
            let (pkcs12, pass): (Binary, String) = term.decode()?;
            builder = builder.identity(
                Identity::from_pkcs12_der(pkcs12.as_slice(), &pass)
                    .map_err(|_| rustler::Error::BadArg)?,
            );
        }
        Err(_) => (),
    };
    match opts.map_get(atoms::use_built_in_root_certs().encode(env)) {
        Ok(term) => {
            builder = builder.tls_built_in_root_certs(term.decode()?);
        }
        Err(_) => (),
    };
    match opts.map_get(atoms::additional_root_certs().encode(env)) {
        Ok(term) => {
            for cert in term.decode::<ListIterator>()? {
                let cert_bin: Binary = cert.decode()?;
                builder = builder.add_root_certificate(
                    Certificate::from_der(cert_bin.as_slice())
                        .map_err(|_| rustler::Error::BadArg)?,
                );
            }
        }
        Err(_) => (),
    };
    let policy = match opts.map_get(atoms::follow_redirects().encode(env)) {
        Ok(term) => match term.decode::<bool>() {
            Ok(true) => Ok(reqwest::redirect::Policy::default()),
            Ok(false) => Ok(reqwest::redirect::Policy::none()),
            Err(_) => match term.decode::<usize>() {
                Ok(n) => Ok(reqwest::redirect::Policy::limited(n)),
                Err(_) => Err(rustler::Error::BadArg),
            },
        },
        Err(_) => Ok(reqwest::redirect::Policy::none()),
    }?;
    builder = builder.redirect(policy);
    let client = builder.build().map_err(
        |e| rustler::Error::RaiseTerm(Box::new(Error::unknown(e.to_string()))),
    )?;
    Ok(ResourceArc::new(ClientResource(RwLock::new(Some(client)))))
}

#[rustler::nif]
fn close_client(resource: ResourceArc<ClientResource>) -> NifResult<Atom> {
    if let Some(_) = resource.0.write().unwrap().take() {
        Ok(atoms::ok())
    } else {
        // already closed
        Err(rustler::Error::BadArg)
    }
}

#[rustler::nif]
fn req_async(
    resource: ResourceArc<ClientResource>,
    pid: LocalPid,
    caller_ref: Term,
    req: Term,
) -> NifResult<Atom> {
    let env = req.get_env();
    let url: String = req.map_get(atoms::url().encode(env))?.decode()?;
    let method: Method = req.map_get(atoms::method().encode(env))?.decode()?;
    // returns BadArg if the client was already closed with close_client
    let client = resource.0.read().unwrap().as_ref().ok_or(rustler::Error::BadArg)?.clone();
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
    match req.map_get(atoms::timeout().encode(env)) {
        Ok(term) => {
            req_builder = req_builder.timeout(Duration::from_millis(term.decode()?));
        }
        Err(_) => (),
    };
    let mut msg_env = OwnedEnv::new();
    let caller_ref = msg_env.save(caller_ref);
    let fut = async move {
        let resp = do_req(req_builder).await;
        msg_env.send_and_clear(&pid, |env| {
            let res = resp.and_then(|r| {
                encode_resp(env.clone(), r).map_err(|_| Error::unknown("failed encoding result"))
            });
            let res = match res {
                Ok(term) => (atoms::ok(), term).encode(env),
                Err(e) => env.error_tuple(e)
            };
            let caller_ref = caller_ref.load(env);
            (atoms::erqwest_response(), caller_ref, res).encode(env)
        });
    };
    HANDLE.spawn(fut);
    Ok(atoms::ok())
}

async fn do_req(
    req: reqwest::RequestBuilder,
) -> Result<(u16, Vec<(String, OwnedBinary)>, OwnedBinary), Error> {
    let resp = req.send().await?;
    let status = resp.status().as_u16();
    // Do we need to handle this or would unwrap do?
    let allocation_failed = || Error {
        code: ErrorCode::Unknown,
        reason: "binary allocation failed".into(),
    };
    let mut headers = Vec::with_capacity(resp.headers().len());
    for (k, v) in resp.headers().iter() {
        let mut v1 = OwnedBinary::new(v.as_bytes().len()).ok_or_else(allocation_failed)?;
        v1.as_mut_slice().write_all(v.as_bytes()).unwrap();
        headers.push((k.as_str().into(), v1))
    }
    let bytes = resp.bytes().await?;
    let mut body = OwnedBinary::new(bytes.len()).ok_or_else(allocation_failed)?;
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

fn load(env: Env, _info: Term) -> bool {
    lazy_static::initialize(&HANDLE);
    rustler::resource!(ClientResource, env);
    true
}

rustler::init!("erqwest", [make_client, close_client, req_async], load = load);
