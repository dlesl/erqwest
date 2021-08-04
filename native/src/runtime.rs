use std::{marker::Send, sync::RwLock};

use rustler::{Atom, Encoder, LocalPid, NifResult, OwnedEnv, ResourceArc};
use std::future::Future;
use tokio::runtime::Handle;

use crate::atoms;

pub struct RuntimeResource {
    handle: Handle,
    shutdown_tx: RwLock<Option<tokio::sync::oneshot::Sender<()>>>,
}

impl RuntimeResource {
    pub fn spawn(&self, future: impl Future<Output = impl Send + 'static> + Send + 'static) {
        self.handle.spawn(future);
    }
    pub fn is_closed(&self) -> bool {
        self.shutdown_tx.read().unwrap().is_none()
    }
}

impl Drop for RuntimeResource {
    fn drop(&mut self) {
        if let Some(shutdown_tx) = self.shutdown_tx.get_mut().unwrap().take() {
            shutdown_tx.send(()).unwrap();
        }
    }
}

struct Monitor {
    pid: LocalPid,
}

impl Drop for Monitor {
    fn drop(&mut self) {
        OwnedEnv::new().send_and_clear(&self.pid, |env| {
            atoms::erqwest_runtime_stopped().encode(env)
        });
    }
}

#[rustler::nif]
fn start_runtime(monitor_pid: LocalPid) -> ResourceArc<RuntimeResource> {
    let monitor = Monitor { pid: monitor_pid };
    let (handle_tx, handle_rx) = std::sync::mpsc::channel();
    let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel();
    std::thread::spawn(move || {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        handle_tx.send(runtime.handle().clone()).unwrap();
        runtime.block_on(shutdown_rx).unwrap();
        drop(monitor);
    });
    let handle = handle_rx.recv().unwrap();
    ResourceArc::new(RuntimeResource {
        handle,
        shutdown_tx: RwLock::new(Some(shutdown_tx)),
    })
}

#[rustler::nif]
fn stop_runtime(runtime: ResourceArc<RuntimeResource>) -> NifResult<Atom> {
    if let Some(shutdown_tx) = runtime.shutdown_tx.write().unwrap().take() {
        shutdown_tx.send(()).unwrap();
        Ok(crate::atoms::ok())
    } else {
        Err(rustler::Error::BadArg)
    }
}
