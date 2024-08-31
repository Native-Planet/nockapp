use std::net::SocketAddr;
use std::sync::mpsc;
use crate::mpsc::{Receiver, SyncSender};

use tokio::sync::oneshot;
use serde::{Deserialize, Serialize};

use axum::{
  routing::{get, post},
  extract::{State, Json},
  response::{Html, Response, Redirect, IntoResponse},
  http::{Method, HeaderMap, Uri, StatusCode},
  Router, Form,
};

use sword::noun::{Atom, D, NO, T, YES};
use sword_macros::tas;

use crown::{AtomExt, Noun, NounExt, Bytes};
use crown::kernel::boot;

use clap::{command, ColorChoice, Parser};
static KERNEL_JAM: &[u8] =
    include_bytes!(concat!(env!("CARGO_MANIFEST_DIR"), "/kernel.jam"));

use crown::kernel::boot::Cli as BootCli;

#[derive(Parser, Debug)]
#[command(about = "Simple todo app", author = "native planet", version, color = ColorChoice::Auto)]
struct TestCli {
    #[command(flatten)]
    boot: BootCli,
}

type Responder = oneshot::Sender<Result<TodoList, StatusCode>>;

#[derive(Debug)]
struct Message {
  action: String,
  data: String,
  resp: Responder,
}

#[derive(Debug)]
struct TodoList {
  done: Vec<String>,
  not_done: Vec<String>,
}

#[tokio::main]
async fn main() {
  println!("Starting todo app");
  let (tx, rx) = mpsc::sync_channel::<Message>(0);
  let app = Router::new()
    .route("/", get(display_todo))
    .route("/add-todo", post(add_todo))
    .route("/del-todo", post(del_todo))
    .route("/toggle-todo", post(toggle_todo))
    .with_state(tx);

  let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
  println!("Server running on http://{}", addr);

  let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
  tokio::spawn(async move {
      axum::serve(listener, app.into_make_service()).await
  });

  manage_kernel(rx).await;
}

async fn manage_kernel(rx: Receiver<Message>) -> Result<(), Box<dyn std::error::Error>> {
  let cli = TestCli::parse();
  let mut kernel = boot::setup_form(KERNEL_JAM, Some(cli.boot))?;

  loop {
      // Start receiving messages
    if let Ok(msg) = rx.recv() {
      if msg.action == "peek" {
        let peek = {
          T(kernel.serf.stack(), &[D(tas!(b"foo")), D(0)])
        };
        let peek_result = kernel.peek(peek)?;
        let res_cell = peek_result.as_cell()?.tail().as_cell()?.tail().as_cell()?;
        let not_done_noun = res_cell.head();
        let done_noun = res_cell.tail();
        let todo_list = TodoList {
          not_done: create_vec(not_done_noun),
          done: create_vec(done_noun),
        };
        let _ = msg.resp.send(Ok(todo_list));
      } else if msg.action == "add" {
        let add = {
          let add_bytes = msg.data.as_str().as_bytes().to_vec();
          let add_atom =
              Atom::from_bytes(kernel.serf.stack(), &Bytes::from(add_bytes)).as_noun();
          T(kernel.serf.stack(), &[D(tas!(b"add")), add_atom])
        };
        let add_result = kernel.poke(add)?;
        println!("Add result: {:?}", add_result);
      } else if msg.action == "del" {
        let del = {
          let del_bytes = msg.data.as_str().as_bytes().to_vec();
          let del_atom =
              Atom::from_bytes(kernel.serf.stack(), &Bytes::from(del_bytes)).as_noun();
          T(kernel.serf.stack(), &[D(tas!(b"delete")), del_atom])
        };
        let del_result = kernel.poke(del)?;
        println!("Del result: {:?}", del_result);
      } else if msg.action == "toggle" {
        let toggle = {
          let toggle_bytes = msg.data.as_str().as_bytes().to_vec();
          let toggle_atom =
              Atom::from_bytes(kernel.serf.stack(), &Bytes::from(toggle_bytes)).as_noun();
          T(kernel.serf.stack(), &[D(tas!(b"toggle")), toggle_atom])
        };
        let toggle_result = kernel.poke(toggle)?;
        println!("Toggle result: {:?}", toggle_result);
      }
    }
  }
  Ok(())
}

async fn display_todo(
  State(sender): State<SyncSender<Message>>,
) -> Html<String> {
    let (resp_tx, resp_rx) = oneshot::channel::<Result<TodoList, StatusCode>>();
    let msg = Message {
        action: "peek".to_string(),
        data: "".to_string(),
        resp: resp_tx,
    };
    if let Err(_) = sender.send(msg) {
        return Html("<div>Peek error</div>".to_string());
    }
    if let Ok(todo_list) = resp_rx.await {
        return build_html(todo_list.unwrap());
    } else {
        return Html("<div>Todo list error</div>".to_string());
    }
}

fn build_html(todo_list: TodoList) -> Html<String> {
    let mut html = String::new();
    html.push_str(r#"<html><head><style>
        h1 {
            text-align: center;
            color: #333;
        }
        .completed { text-decoration: line-through; }
        .task-item { 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            margin-bottom: 5px; 
            width: 100%;
            border-bottom: 1px solid #ccc;
            padding-bottom: 5px;
        }
        .task-content {
            flex-grow: 1;
            margin: 0 10px;
        }
        .delete-btn { 
            color: red; 
            cursor: pointer; 
            background: none;
            border: none;
            padding: 5px;
        }
        ul {
            list-style-type: none;
            padding: 0;
            width: 100%;
            max-width: 600px;
            margin: 0 auto;
        }
        form {
            display: flex;
            align-items: center;
        }
        input[type="checkbox"] {
            margin-top: 22px;
            vertical-align: middle;
        }
    </style></head><body>"#);
    html.push_str("<h1>Todo List</h1>");
    
    // Add new task form
    html.push_str(r#"<form action='/add-todo' method='post' style="max-width: 600px; margin: 0 auto;">
        <input type='text' name='new_task' placeholder='Enter new task' style="flex-grow: 1;">
        <button type='submit'>Add Task</button>
    </form>"#);
    
    // Incomplete tasks
    html.push_str("<ul>");
    for task in &todo_list.not_done {
        html.push_str(&format!(r#"<li class="task-item">
            <form action='/toggle-todo' method='post'>
                <input type='checkbox' name='toggle_task' value='{}' onchange='this.form.submit()'>
            </form>
            <span class="task-content">{}</span>
            <form action='/del-todo' method='post'>
                <input type='hidden' name='del_task' value='{}'>
                <button type='submit' class="delete-btn">X</button>
            </form>
        </li>"#, task, task, task));
    }
    html.push_str("</ul>");
    
    // Completed tasks
    html.push_str("<ul>");
    for task in &todo_list.done {
        html.push_str(&format!(r#"<li class="task-item">
            <form action='/toggle-todo' method='post'>
                <input type='hidden' name='toggle_task' value='{}'>
                <input type='checkbox' name='toggle_task' value='{}' checked onchange='this.form.submit()'>
            </form>
            <span class="task-content completed">{}</span>
            <form action='/del-todo' method='post'>
                <input type='hidden' name='del_task' value='{}'>
                <button type='submit' class="delete-btn">X</button>
            </form>
        </li>"#, task, task, task, task));
    }
    html.push_str("</ul>");
    
    html.push_str("</body></html>");
    Html(html)
}

#[derive(Debug, Deserialize)]
struct NewTask {
  new_task: String,
}

#[derive(Debug, Deserialize)]
struct DelTask {
  del_task: String,
}

#[derive(Debug, Deserialize)]
struct ToggleTask {
  toggle_task: String,
}

async fn add_todo(
    State(sender): State<SyncSender<Message>>,
    Form(form_data): Form<NewTask>,
) -> impl IntoResponse {
    let (resp_tx, resp_rx) = oneshot::channel::<Result<TodoList, StatusCode>>();
    let msg = Message {
        action: "add".to_string(),
        data: form_data.new_task,
        resp: resp_tx,
    };
    if let Err(_) = sender.send(msg) {
        return Html("<div>Poke error</div>".to_string()).into_response();
    }
    Redirect::to("/").into_response()
}

async fn del_todo(
    State(sender): State<SyncSender<Message>>,
    Form(form_data): Form<DelTask>,
) -> impl IntoResponse {
    let (resp_tx, resp_rx) = oneshot::channel::<Result<TodoList, StatusCode>>();
    let msg = Message {
        action: "del".to_string(),
        data: form_data.del_task.trim_end_matches(|c: char| !c.is_ascii()).to_string(),
        resp: resp_tx,
    };
    if let Err(_) = sender.send(msg) {
        return Html("<div>Poke error</div>".to_string()).into_response();
    }
    Redirect::to("/").into_response()
}

async fn toggle_todo(
    State(sender): State<SyncSender<Message>>,
    Form(form_data): Form<ToggleTask>,
) -> impl IntoResponse {
    let (resp_tx, resp_rx) = oneshot::channel::<Result<TodoList, StatusCode>>();
    let msg = Message {
        action: "toggle".to_string(),
        data: form_data.toggle_task.trim_end_matches(|c: char| !c.is_ascii()).to_string(),
        resp: resp_tx,
    };
    if let Err(_) = sender.send(msg) {
        return Html("<div>Poke error</div>".to_string()).into_response();
    }
    Redirect::to("/").into_response()
}

fn create_vec(n: Noun) -> Vec<String> {
    fn recursive_extract(n: Noun) -> Vec<String> {
        if n.is_atom() {
            Vec::new()
        } else {
            let cell = n.as_cell().expect("Expected a cell");
            let head = cell.head();
            let tail = cell.tail();
            
            let d = if let Ok(atom) = head.as_atom() {
                // Change this part
                if let Some(direct) = atom.direct() {
                    direct.data().to_le_bytes().to_vec()
                } else {
                    head.as_indirect().expect("Expected indirect noun").as_bytes().to_vec()
                }
            } else {
                head.as_indirect().expect("Expected indirect noun").as_bytes().to_vec()
            };
            let s = String::from_utf8_lossy(&d).into_owned();
            let mut tasks = vec![s];
            tasks.extend(recursive_extract(tail));
            tasks
        }
    }

    recursive_extract(n)
}