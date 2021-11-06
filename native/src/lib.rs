use rustler::{nif, Env, NifResult, NifUnitEnum, Term};

mod client;
mod req;
mod runtime;
mod utils;

mod atoms {
    rustler::atoms! {
        additional_root_certs,
        bad_opt,
        basic_auth,
        body,
        cancel,
        cancelled,
        chunk,
        client_builder_error,
        connect_timeout,
        cookie_store,
        danger_accept_invalid_certs,
        danger_accept_invalid_hostnames,
        erqwest_response,
        erqwest_runtime_stopped,
        error,
        fin,
        follow_redirects,
        gzip,
        headers,
        https_only,
        identity,
        length,
        method,
        next,
        ok,
        period,
        pool_idle_timeout,
        pool_max_idle_per_host,
        proxy,
        reason,
        reply,
        response_body,
        status,
        stream,
        stream_response,
        timeout,
        url,
        use_built_in_root_certs,
    }
}

fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(client::ClientResource, env);
    rustler::resource!(req::ReqHandle, env);
    rustler::resource!(runtime::RuntimeResource, env);
    true
}

#[derive(NifUnitEnum)]
enum Feature {
    Cookies,
    Gzip,
}

#[nif]
fn feature(f: Term) -> NifResult<bool> {
    use Feature::*;
    Ok(match f.decode()? {
        Cookies => cfg!(feature = "cookies"),
        Gzip => cfg!(feature = "gzip"),
    })
}

rustler::init!(
    "erqwest_nif",
    [
        runtime::start_runtime,
        runtime::stop_runtime,
        client::make_client,
        client::close_client,
        req::req,
        req::cancel,
        req::send,
        req::finish_send,
        req::read,
        req::cancel_stream,
        feature
    ],
    load = load
);
