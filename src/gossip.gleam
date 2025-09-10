import argv
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

// Messages the actor understands. `e` is a type parameter (element type).
pub type State {
  State(
    internal: #(
      Float,
      Float,
      Int,
      String,
      String,
      List(#(Int, process.Subject(Message))),
    ),
    stack: List(String),
  )
}

// ----- Messages the actor understands -----
pub type Message {
  Shutdown
  SetInternal(
    #(Float, Float, Int, String, String, List(#(Int, process.Subject(Message)))),
  )
  // GetInternal(process.Subject(Int))
  Push(String)
  Pop(process.Subject(Result(String, Nil)))
}

// ----- Message handler -----
fn handle_message(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    Shutdown -> actor.stop()

    SetInternal(#(v1, v2, v3, v4, v5, v6)) -> {
      actor.continue(State(#(v1, v2, v3, v4, v5, v6), state.stack))
    }

    // GetInternal(client) -> {
    //   process.send(client, state.internal)
    //   actor.continue(state)
    // }
    Push(value) -> {
      echo value
      actor.continue(State(state.internal, [value, ..state.stack]))
    }

    Pop(client) ->
      case state.stack {
        [] -> {
          process.send(client, Error(Nil))
          actor.continue(state)
        }
        [first, ..rest] -> {
          process.send(client, Ok(first))
          actor.continue(State(state.internal, rest))
        }
      }
  }
}

pub fn main() {
  // Start the actor with an empty stack
  // let assert Ok(logger_started) =
  //   actor.new([])
  //   |> actor.on_message(handle_message)
  //   |> actor.start

  case argv.load().arguments {
    args -> handle_args(args)
  }
}

fn handle_args(args) {
  io.println("Hello from rippy!")

  //Grab the first two input parameters, default to 0 if not present
  let number_of_nodes = case nth(args, 0) {
    Ok(arg) -> arg
    Error(_) -> "0"
  }

  let topology = case nth(args, 1) {
    Ok(arg) -> arg
    Error(_) -> "0"
  }

  let algorithm = case nth(args, 2) {
    Ok(arg) -> arg
    Error(_) -> "0"
  }

  //Turn inputs into ints to be used. Default to 0 in event that input is not an int
  let number_of_nodes = case int.parse(number_of_nodes) {
    Ok(number_of_nodes) -> number_of_nodes
    Error(_) -> 0
  }

  // echo number_of_nodes
  // echo topology
  // echo algorithm

  // full, 3D, line, or imp3D default
  let topology_number = case topology {
    "full" -> "full"
    "3D" -> "3D"
    "line" -> "line"
    "imp3D" -> "imp3D"
    _ -> "full"
  }

  // let topology = case int.parse(topology) {
  //   Ok(topology) -> topology
  //   Error(_) -> 0
  // }

  // let algorithm = case algorithm {
  //   Ok(algorithm) -> algorithm
  //   Error(_) -> "Full"
  // }

  let task = list.range(0, number_of_nodes - 1)

  // echo task

  let assert Ok(default_actor) =
    actor.new(State(#(0.0, 0.0, 0, topology, algorithm, []), []))
    |> actor.on_message(handle_message)
    |> actor.start

  let actor_list =
    list.map(task, fn(n) {
      let assert Ok(started) =
        actor.new(State(#(0.0, 0.0, 0, topology, algorithm, []), []))
        |> actor.on_message(handle_message)
        |> actor.start

      #(n, started.data)
    })

  // list.each(actor_list, fn(n) { process.send(n, Push("Alice")) })

  set_up_topology(actor_list, number_of_nodes, topology, algorithm, #(
    0,
    default_actor.data,
  ))

  // echo task
  // let assert Ok(started) =
  //   actor.new(State(0, []))
  //   |> actor.on_message(handle_message)
  //   |> actor.start
  process.sleep(5000)
}

fn nth(xs: List(String), i: Int) -> Result(String, Nil) {
  case xs {
    [] -> Error(Nil)
    // list too short
    [x, ..rest] ->
      case i {
        0 -> Ok(x)
        // found the element
        _ -> nth(rest, i - 1)
        // keep searching
      }
  }
}

fn nth_actor(
  xs: List(#(Int, process.Subject(Message))),
  i: Int,
) -> Result(#(Int, process.Subject(Message)), Nil) {
  case xs {
    [] -> Error(Nil)
    // list too short
    [x, ..rest] ->
      case i {
        0 -> Ok(x)
        // found the element
        _ -> nth_actor(rest, i - 1)
        // keep searching
      }
  }
}

fn set_up_topology(
  actor_list,
  number_of_nodes,
  topology,
  algorithm,
  default_actor,
) {
  // case topology {
  //   "full" -> "full"
  //   "3D" -> "3D"
  //   "line" -> "line"
  //   "imp3D" -> "imp3D"
  //   _ -> "full"
  // }

  // set_up_full_topology(actor_list, topology, algorithm, default_actor)
  set_up_line_topology(actor_list, topology, algorithm, default_actor)
}

fn set_up_full_topology(actor_list, topology, algorithm, default_actor) {
  // echo actor_list

  list.each(actor_list, fn(actor_tuple) {
    // let hi = #(0.0, 0.0, 0, topology, algorithm, actor_list)
    // process.send(actor, SetInternal(hi))

    let #(actor_number, actor) = actor_tuple

    // echo hi

    let neighbor_list_length = list.length(actor_list) - 1

    let neighbor_list = list.range(0, neighbor_list_length - 1)

    // echo neighbor_list
    // let test_subject = process.new_subject(Message)

    // let first_actor = case nth_actor(actor_list, 0) {
    //   Ok(arg) -> arg
    //   Error(_) -> default_actor
    // }

    // list.map(neighbor_list, fn(n){
    // let offset = 0
    let neighbor_list =
      list.map(neighbor_list, fn(n) {
        let offset = case n >= actor_number {
          True -> 1
          False -> 0
        }

        let index = n + offset

        let filtered_actor = case nth_actor(actor_list, index) {
          Ok(arg) -> arg
          Error(_) -> default_actor
        }

        // echo filtered_actor

        filtered_actor
      })
    echo neighbor_list
    //Set the internal state with updated topology neighbors

    let internal_state = #(0.0, 0.0, 0, topology, algorithm, neighbor_list)
    process.send(actor, SetInternal(internal_state))
    //   let index = case actor 

    // let first_actor = case nth_actor(actor_list, 0) {
    // Ok(arg) -> arg
    // Error(_) -> default_actor
    // }

    // })
    // nth_actor(actor_list, 1)
    // nth_actor()
    // list.each(actor_list, fn(actor2) {

    //   // case actor == actor2 {
    //   //   True -> 
    //   //   False ->
    //   // }
    // })
  })
}

fn set_up_line_topology(actor_list, topology, algorithm, default_actor) {
  // echo actor_list

  list.each(actor_list, fn(actor_tuple) {
    // let hi = #(0.0, 0.0, 0, topology, algorithm, actor_list)
    // process.send(actor, SetInternal(hi))

    let #(actor_number, actor) = actor_tuple

    // echo hi

    let end_actor = list.length(actor_list) - 1

    // echo actor_number
    // echo end_actor

    let neighbor_list = case actor_number == 0 {
      True -> list.range(0, 0)
      False ->
        case actor_number == end_actor {
          True -> list.range(0, 0)
          False -> list.range(0, 1)
        }
    }

    // echo neighbor_list
    // let test_subject = process.new_subject(Message)

    // let first_actor = case nth_actor(actor_list, 0) {
    //   Ok(arg) -> arg
    //   Error(_) -> default_actor
    // }

    // list.map(neighbor_list, fn(n){
    // let offset = 0
    let neighbor_list =
      list.map(neighbor_list, fn(n) {
        // let offset = case n >= actor_number {
        //   True -> 1
        //   False -> 0
        // }
        let offset = case actor_number == 0 {
          True -> 2
          False ->
            case actor_number == end_actor {
              True -> 0
              False -> 0
            }
        }

        let offset2 = case n {
          0 -> -1
          1 -> 1
          _ -> 0
        }
        let index = actor_number + offset + offset2

        // index
        let filtered_actor = case nth_actor(actor_list, index) {
          Ok(arg) -> arg
          Error(_) -> default_actor
        }
        // // echo filtered_actor

        filtered_actor
      })
    // echo neighbor_list
    //Set the internal state with updated topology neighbors

    let internal_state = #(0.0, 0.0, 0, topology, algorithm, neighbor_list)
    process.send(actor, SetInternal(internal_state))
  })
}
