use std::sync::RwLock;

use reqwest::{Certificate, Identity};
use rustler::{Atom, Encoder, Env, MapIterator, NifMap, NifResult, NifUnitEnum, ResourceArc, Term};
use rustler::{Binary, ListIterator};

use crate::utils::{maybe_timeout, DecodeOrRaise};
use crate::{atoms, runtime::RuntimeResource};

#[derive(NifUnitEnum)]
enum Proxy {
    System,
    NoProxy,
}

#[derive(NifUnitEnum)]
enum ProxyType {
    Http,
    Https,
    All,
}

#[derive(NifMap)]
struct ProxySpecBase {
    url: String,
}

pub struct ClientResource {
    pub client: RwLock<Option<reqwest::Client>>,
    pub runtime: ResourceArc<RuntimeResource>,
}

// This is marked as "dirty" because it can take quite a while (around 30 ms according to
// a quick timer:tc in the shell). `perf` suggests it is related to initialising TLS.
#[rustler::nif(schedule = "DirtyCpu")]
fn make_client(
    env: Env,
    runtime: ResourceArc<RuntimeResource>,
    opts: Term,
) -> NifResult<ResourceArc<ClientResource>> {
    let _ = env;
    if runtime.is_closed() {
        return Err(rustler::Error::BadArg);
    }
    let mut builder = reqwest::ClientBuilder::new();
    for (k, v) in opts.decode::<MapIterator>()? {
        let k: Atom = k.decode_or_raise()?;
        if k == atoms::identity() {
            let (pkcs12, pass): (Binary, String) = v.decode_or_raise()?;
            builder = builder.identity(
                Identity::from_pkcs12_der(pkcs12.as_slice(), &pass)
                    .map_err(|_| rustler::Error::BadArg)?,
            );
        } else if k == atoms::use_built_in_root_certs() {
            builder = builder.tls_built_in_root_certs(v.decode_or_raise()?);
        } else if k == atoms::additional_root_certs() {
            for cert in v.decode::<ListIterator>()? {
                let cert_bin: Binary = cert.decode_or_raise()?;
                builder = builder.add_root_certificate(
                    Certificate::from_der(cert_bin.as_slice())
                        .map_err(|_| rustler::Error::BadArg)?,
                );
            }
        } else if k == atoms::follow_redirects() {
            let policy = match v.decode::<bool>() {
                Ok(true) => Ok(reqwest::redirect::Policy::default()),
                Ok(false) => Ok(reqwest::redirect::Policy::none()),
                Err(_) => match v.decode::<usize>() {
                    Ok(n) => Ok(reqwest::redirect::Policy::limited(n)),
                    Err(_) => Err(rustler::Error::BadArg),
                },
            }?;
            builder = builder.redirect(policy);
        } else if k == atoms::danger_accept_invalid_hostnames() {
            builder = builder.danger_accept_invalid_hostnames(v.decode_or_raise()?);
        } else if k == atoms::danger_accept_invalid_certs() {
            builder = builder.danger_accept_invalid_certs(v.decode_or_raise()?);
        } else if k == atoms::connect_timeout() {
            if let Some(timeout) = maybe_timeout(v)? {
                builder = builder.connect_timeout(timeout);
            }
        } else if k == atoms::timeout() {
            if let Some(timeout) = maybe_timeout(v)? {
                builder = builder.timeout(timeout);
            }
        } else if k == atoms::pool_idle_timeout() {
            builder = builder.pool_idle_timeout(maybe_timeout(v)?);
        } else if k == atoms::pool_max_idle_per_host() {
            builder = builder.pool_max_idle_per_host(v.decode_or_raise()?);
        } else if k == atoms::https_only() {
            builder = builder.https_only(v.decode_or_raise()?);
        } else if k == atoms::cookie_store() {
            #[cfg(feature = "cookies")]
            {
                builder = builder.cookie_store(v.decode_or_raise()?);
            }
            #[cfg(not(feature = "cookies"))]
            {
                return Err(rustler::Error::RaiseAtom("cookies_not_enabled"));
            }
        } else if k == atoms::gzip() {
            #[cfg(feature = "gzip")]
            {
                builder = builder.gzip(v.decode_or_raise()?);
            }
            #[cfg(not(feature = "gzip"))]
            {
                return Err(rustler::Error::RaiseAtom("gzip_not_enabled"));
            }
        } else if k == atoms::proxy() {
            match v.decode::<Proxy>() {
                Ok(Proxy::System) => (),
                Ok(Proxy::NoProxy) => {
                    builder = builder.no_proxy();
                }
                Err(_) => {
                    for proxy in v.decode::<ListIterator>()? {
                        let (proxy_type, proxy_spec): (ProxyType, Term) =
                            proxy.decode_or_raise()?;
                        let ProxySpecBase { url } = proxy_spec.decode_or_raise()?;
                        let mut proxy = match proxy_type {
                            ProxyType::Http => reqwest::Proxy::http(url),
                            ProxyType::Https => reqwest::Proxy::https(url),
                            ProxyType::All => reqwest::Proxy::all(url),
                        }
                        .map_err(|_| rustler::Error::BadArg)?;
                        if let Ok(term) = proxy_spec.map_get(atoms::basic_auth().encode(env)) {
                            let (username, password) = term.decode_or_raise()?;
                            proxy = proxy.basic_auth(username, password);
                        }
                        builder = builder.proxy(proxy);
                    }
                }
            }
        } else {
            return Err(rustler::Error::RaiseTerm(Box::new((atoms::bad_opt(), k))));
        }
    }
    let client = builder.build().map_err(|e| {
        rustler::Error::RaiseTerm(Box::new((atoms::client_builder_error(), e.to_string())))
    })?;
    Ok(ResourceArc::new(ClientResource {
        client: RwLock::new(Some(client)),
        runtime,
    }))
}

#[rustler::nif]
fn close_client(resource: ResourceArc<ClientResource>) -> NifResult<Atom> {
    if resource.client.write().unwrap().take().is_some() {
        Ok(atoms::ok())
    } else {
        // already closed
        Err(rustler::Error::BadArg)
    }
}
