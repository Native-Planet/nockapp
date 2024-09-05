// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

//use std::any::type_name; // debug

use clap::Parser;
use std::sync::mpsc;
use std::sync::Arc;
use tokio::sync::oneshot;

use crown::kernel::boot::Cli as BootCli;
use crown::kernel::boot;
use crown::Bytes;
use crown::AtomExt;

use sword::noun::{D, T, Atom, Noun};
use sword_macros::tas;

static KERNEL_JAM: &[u8] = include_bytes!(concat!(env!("CARGO_MANIFEST_DIR"), "/imgproc.jam"));

type Responder = oneshot::Sender<Result<Vec<u8>, String>>;

struct RequestMessage {
    image_data: Vec<u8>,
    resp: Responder,
    mime: Noun,
}

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct TauriCli {
    #[command(flatten)]
    boot: BootCli,
}

#[tauri::command]
async fn do_fake(state: tauri::State<'_, Arc<mpsc::SyncSender<RequestMessage>>>) -> Result<String, String> {
    let (resp_tx, resp_rx) = oneshot::channel();
    println!("Fake command received");
    let request = RequestMessage {
        image_data: vec![],
        mime: D(tas!(b"fake")),
        resp: resp_tx,
    };
    let _ = state.send(request);
    let result = resp_rx.await;
    match result {
        Ok(body) => Ok(String::from_utf8(body.unwrap()).expect("Failed to convert body to string")),
        Err(e) => Err(e.to_string()),
    }
}

#[tauri::command]
async fn process_image(image_data: Vec<u8>, state: tauri::State<'_, Arc<mpsc::SyncSender<RequestMessage>>>) -> Result<String, String> {
    let (resp_tx, resp_rx) = oneshot::channel();
    println!("Command received");
    let request = RequestMessage {
        image_data,
        mime: D(tas!(b"png")),
        resp: resp_tx,
    };
    let _ = state.send(request);
    let result = resp_rx.await;
    match result {
        Ok(body) => Ok(String::from_utf8(body.unwrap()).expect("Failed to convert body to string")),
        Err(e) => Err(e.to_string()),
    }
}

async fn manage_kernel(rx: mpsc::Receiver<RequestMessage>) {
    let cli = TauriCli::parse_from(&["", "--new"]);
    let mut kernel = boot::setup_form(KERNEL_JAM, Some(cli.boot)).expect("Failed to setup kernel");
    loop {
        let Ok(req) = rx.recv() else {
            continue;
        };
        println!("Request received in manage_kernel");
        let png_bytes = req.image_data.to_vec();
        let mut png_atoms = Vec::new();
        png_atoms.push(req.mime);
        for chunk in png_bytes.chunks(1) {
            let atom = Atom::from_bytes(kernel.serf.stack(), &Bytes::from(chunk.to_vec())).as_noun();
            png_atoms.push(atom);
        }
        png_atoms.push(D(0));
        let poke = T(kernel.serf.stack(), &png_atoms);
        println!("Poke noun created");
        let effect = kernel.poke(poke).unwrap().as_cell().expect("Failed to get list effect")
                                .head().as_cell().expect("Failed to get effect");
        let len = effect.head().as_atom().expect("Failed to get len atom").direct().expect("Failed to get len direct").data();
        let mut body = effect.tail().as_atom().expect("Failed to get body octet").as_bytes().to_vec();
        body.truncate(len as usize);
        req.resp.send(Ok(body)).expect("Failed to send response");
        
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let (tx, rx) = mpsc::sync_channel::<RequestMessage>(0);
    let tx = Arc::new(tx);

    tokio::spawn(manage_kernel(rx));
    tauri::Builder::default()
        .manage(Arc::clone(&tx))
        .invoke_handler(tauri::generate_handler![process_image, do_fake])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
    Ok(())
}