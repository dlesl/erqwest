use std::sync::RwLock;

use reqwest::{Certificate, Identity};
use rustler::{Atom, Encoder, Env, NifMap, NifResult, NifUnitEnum, ResourceArc, Term};
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

#[rustler::nif]
fn make_client(
    env: Env,
    runtime: ResourceArc<RuntimeResource>,
    opts: Term,
) -> NifResult<ResourceArc<ClientResource>> {
    let _ = env;
    if !opts.is_map() || runtime.is_closed() {
        return Err(rustler::Error::BadArg);
    }
    let mut builder = reqwest::ClientBuilder::new();
    if let Ok(term) = opts.map_get(atoms::identity().encode(env)) {
        let (pkcs12, pass): (Binary, String) = term.decode_or_raise()?;
        builder = builder.identity(
            Identity::from_pkcs12_der(pkcs12.as_slice(), &pass)
                .map_err(|_| rustler::Error::BadArg)?,
        );
    };
    if let Ok(term) = opts.map_get(atoms::use_built_in_root_certs().encode(env)) {
        builder = builder.tls_built_in_root_certs(term.decode_or_raise()?);
    };
    if let Ok(term) = opts.map_get(atoms::additional_root_certs().encode(env)) {
        for cert in term.decode::<ListIterator>()? {
            let cert_bin: Binary = cert.decode_or_raise()?;
            builder = builder.add_root_certificate(
                Certificate::from_der(cert_bin.as_slice()).map_err(|_| rustler::Error::BadArg)?,
            );
        }
    };
    if let Ok(term) = opts.map_get(atoms::follow_redirects().encode(env)) {
        let policy = match term.decode::<bool>() {
            Ok(true) => Ok(reqwest::redirect::Policy::default()),
            Ok(false) => Ok(reqwest::redirect::Policy::none()),
            Err(_) => match term.decode::<usize>() {
                Ok(n) => Ok(reqwest::redirect::Policy::limited(n)),
                Err(_) => Err(rustler::Error::BadArg),
            },
        }?;
        builder = builder.redirect(policy);
    };
    if let Ok(term) = opts.map_get(atoms::danger_accept_invalid_hostnames().encode(env)) {
        builder = builder.danger_accept_invalid_hostnames(term.decode_or_raise()?);
    };
    if let Ok(term) = opts.map_get(atoms::danger_accept_invalid_certs().encode(env)) {
        builder = builder.danger_accept_invalid_certs(term.decode_or_raise()?);
    };
    if let Ok(term) = opts.map_get(atoms::connect_timeout().encode(env)) {
        if let Some(timeout) = maybe_timeout(term)? {
            builder = builder.connect_timeout(timeout);
        }
    };
    if let Ok(term) = opts.map_get(atoms::timeout().encode(env)) {
        if let Some(timeout) = maybe_timeout(term)? {
            builder = builder.timeout(timeout);
        }
    };
    if let Ok(term) = opts.map_get(atoms::pool_idle_timeout().encode(env)) {
        builder = builder.pool_idle_timeout(maybe_timeout(term)?);
    };
    if let Ok(term) = opts.map_get(atoms::pool_max_idle_per_host().encode(env)) {
        builder = builder.pool_max_idle_per_host(term.decode_or_raise()?);
    };
    if let Ok(term) = opts.map_get(atoms::https_only().encode(env)) {
        builder = builder.https_only(term.decode_or_raise()?);
    };
    #[cfg(feature = "cookies")]
    if let Ok(term) = opts.map_get(atoms::cookie_store().encode(env)) {
        builder = builder.cookie_store(term.decode_or_raise()?);
    };
    #[cfg(not(feature = "cookies"))]
    if opts.map_get(atoms::cookie_store().encode(env)).is_ok() {
        return Err(rustler::Error::RaiseAtom("cookies_not_enabled"));
    };
    if let Ok(term) = opts.map_get(atoms::proxy().encode(env)) {
        match term.decode::<Proxy>() {
            Ok(Proxy::System) => (),
            Ok(Proxy::NoProxy) => {
                builder = builder.no_proxy();
            }
            Err(_) => {
                for proxy in term.decode::<ListIterator>()? {
                    let (proxy_type, proxy_spec): (ProxyType, Term) = proxy.decode_or_raise()?;
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
    };
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
