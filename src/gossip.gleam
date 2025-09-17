import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/time/timestamp

type Rule =
  #(
    fn(Int, Int, Int) -> Bool,
    fn(
      Int,
      Int,
      Int,
      Int,
      Int,
      // predicate (x,y,z) -> true/false
    ) ->
      #(Int, Int, Int),
    // mapper (n,x,y,z) -> new coords
  )

// Messages the actor understands. `e` is a type parameter (element type).
pub type State {
  State(
    internal: #(
      Float,
      Float,
      Int,
      String,
      String,
      List(#(Int, process.Subject(Message), Int, Int, Int)),
      Int,
      Float,
      Int,
      List(#(Int, process.Subject(Message), Int, Int, Int)),
      List(Int),
      List(Int),
      List(#(Int, process.Subject(Message), Int, Int, Int)),
      Float,
      Float,
    ),
    stack: List(Int),
    ratio_stack: List(Float),
    prev_ratio_stack: List(#(Int, Float)),
  )
}

// ----- Messages the actor understands -----
pub type Message {
  Shutdown
  Terminated(Int)
  UpdateTerminated(List(Int))

  StepGossip
  StepPushSum(process.Subject(Message))
  SendRumor
  SendPushSum(Float, Float)
  InternalStateGossip(State)
  InternalStatePushSum(State, process.Subject(Message))
  SetInternal(
    #(
      Float,
      Float,
      Int,
      String,
      String,
      List(#(Int, process.Subject(Message), Int, Int, Int)),
      Int,
      Float,
      Int,
      List(#(Int, process.Subject(Message), Int, Int, Int)),
      List(Int),
      List(Int),
      List(#(Int, process.Subject(Message), Int, Int, Int)),
      Float,
      Float,
    ),
  )
  GetInternalGossip(process.Subject(Message))
  GetInternalPushSum(process.Subject(Message))
  // Push(String)
  // PopGossip(process.Subject(Result(Int, Nil)))
}

// ----- Message handler -----
fn handle_message(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    Shutdown -> actor.stop()
    Terminated(terminated_actor) -> {
      let #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = state.internal

      let new_terminated = case
        //todo not finding terminated actor for some reason in comparison
        list.find(terminated_list, fn(k) { k == terminated_actor })
      {
        Ok(_) -> {
          terminated_list
        }
        // prints "8"
        Error(_) -> {
          [terminated_actor, ..terminated_list]
        }
      }

      // echo new_terminated
      let new_state = #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        new_terminated,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      )

      // echo new_terminated

      // io.println("Terminated: " <> int.to_string(terminated_actor))

      list.each(all_actors, fn(actor_tuple) {
        let #(_, actor, _, _, _) = actor_tuple
        process.send(actor, UpdateTerminated(new_terminated))
      })

      actor.continue(State(
        new_state,
        state.stack,
        state.ratio_stack,
        state.prev_ratio_stack,
      ))
    }

    UpdateTerminated(terminated_actor_list) -> {
      let #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = state.internal

      let new_state = #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_actor_list,
        terminated_neighbor_list,
        neighbor_list,
        start_s,
        start_w,
      )

      actor.continue(State(
        new_state,
        state.stack,
        state.ratio_stack,
        state.prev_ratio_stack,
      ))
    }
    SetInternal(#(
      v1,
      v2,
      v3,
      v4,
      v5,
      v6,
      v7,
      v8,
      v9,
      v10,
      v11,
      v12,
      v13,
      v14,
      v15,
    )) -> {
      actor.continue(State(
        #(v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15),
        state.stack,
        state.ratio_stack,
        state.prev_ratio_stack,
      ))
    }
    StepGossip -> {
      let #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = state.internal

      let neighbor_list_length = list.length(not_terminated_neighbors)
      // let neighbor_list_length = neighbor_list_length - 1

      let random_index = int.random(neighbor_list_length)

      let assert Ok(default_actor) =
        actor.new(
          State(
            #(
              0.0,
              0.0,
              0,
              topology,
              algorithm,
              [],
              0,
              0.0,
              -1,
              [],
              [],
              [],
              [],
              0.0,
              0.0,
            ),
            [],
            [],
            [],
          ),
        )
        |> actor.on_message(handle_message)
        |> actor.start

      let default_placeholder = #(0, default_actor.data, 0, 0, 0)

      let result = nth_actor(not_terminated_neighbors, random_index)

      let #(v1, random_neighbor, v2, v3, v4) = case result {
        Ok(result) -> result
        Error(_) -> default_placeholder
      }

      case rumors > 0 && rumors < 10 {
        True -> process.send(random_neighbor, SendRumor)
        False -> Nil
      }

      process.send(default_actor.data, Shutdown)
      actor.continue(State(
        state.internal,
        state.stack,
        state.ratio_stack,
        state.prev_ratio_stack,
      ))
    }
    StepPushSum(client) -> {
      let #(
        s,
        w,
        can_send,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = state.internal

      // echo can_send
      let ratio = s /. w
      // echo start_s == s
      // echo start_s
      let new_s = s /. 2.0
      let new_w = w /. 2.0

      let new_ratio = [ratio, ..state.ratio_stack]

      let ratio_stack_length = list.length(new_ratio)
      // echo not_terminated_neighbors

      let id_list = extract_ids(not_terminated_neighbors)
      let terminated_ids = intersect(id_list, terminated_list)
      let not_term_neighbors =
        filter_not_in(not_terminated_neighbors, terminated_ids)

      let send_list_length = list.length(not_term_neighbors)

      // echo not_term_neighbors
      // echo terminated_list
      let terminated_list_length = list.length(terminated_list)

      case terminated_list_length == number_of_nodes {
        True -> {
          let later = timestamp.system_time()

          let time_later_ms = timestamp.to_unix_seconds(later)
          // echo time_later_ms -. initial_time
          let new_time = time_later_ms -. initial_time

          io.println("Done: " <> float.to_string(new_time))
        }
        False -> {
          Nil
        }
      }

      // let default_actor = create_default_actor()
      let default_placeholder = #(0, client, 0, 0, 0)
      let #(step_s, step_w) = case send_list_length > 0 {
        True -> {
          let random_index = int.random(send_list_length)

          let result = nth_actor(not_term_neighbors, random_index)

          let neighbor_tuple = case result {
            Ok(result) -> result
            Error(_) -> default_placeholder
          }

          // echo neighbor_tuple == default_placeholder

          let #(_, random_neighbor, _, _, _) = neighbor_tuple

          case can_send == 1 {
            True -> {
              process.send(random_neighbor, SendPushSum(new_s, new_w))
              #(new_s, new_w)
            }
            False -> {
              #(s, w)
            }
          }
          // process.send(random_neighbor, SendPushSum(new_s, new_w))
          // process.send(default_actor, Shutdown)
        }

        False -> {
          #(s, w)
        }
      }

      // echo terminated_ids
      // echo list.length(not_term_neighbors)

      let new_state = #(
        step_s,
        step_w,
        can_send,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_term_neighbors,
        start_s,
        start_w,
      )

      let is_in_term_list = case
        list.find(terminated_list, fn(k) { k == actor_id })
      {
        Ok(_) -> {
          True
        }
        Error(_) -> {
          False
        }
      }

      let continue1 = case ratio_stack_length == 2 {
        True -> {
          //Check to see if ratio changed by less than 10^-10

          // let [ratio1, ratio2, ..rest] = new_ratio

          let continue2 = case new_ratio {
            [a, b] -> {
              let diff = b -. a
              // echo terminated_list
              // echo diff
              //TODO Stop spamming Terminated messages, check to see if it is in terminated list
              case
                diff <. 0.0000000001 && is_in_term_list == False && s != start_s
              {
                True -> {
                  //Actor terminated, send and update central actor
                  // echo terminated_list
                  process.send(client, Terminated(actor_id))
                }
                False -> {
                  Nil
                }
              }

              //Reset ratio stack
              actor.continue(State(
                new_state,
                state.stack,
                [],
                state.prev_ratio_stack,
              ))
            }

            _ -> {
              actor.continue(State(
                new_state,
                state.stack,
                [],
                state.prev_ratio_stack,
              ))
            }
          }

          continue2
        }

        False -> {
          actor.continue(State(
            new_state,
            state.stack,
            new_ratio,
            state.prev_ratio_stack,
          ))
        }
      }

      continue1
    }
    SendRumor -> {
      let #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = state.internal

      let new_rumor_count = rumors + 1

      let new_state = #(
        s,
        w,
        new_rumor_count,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      )

      actor.continue(State(
        new_state,
        state.stack,
        state.ratio_stack,
        state.prev_ratio_stack,
      ))
    }
    SendPushSum(sent_s, sent_w) -> {
      let #(
        s,
        w,
        can_send,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = state.internal

      let new_can_send = 1
      let new_s = s +. sent_s
      let new_w = w +. sent_w

      let new_state = #(
        new_s,
        new_w,
        new_can_send,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      )

      actor.continue(State(
        new_state,
        state.stack,
        state.ratio_stack,
        state.prev_ratio_stack,
      ))
    }
    GetInternalGossip(client) -> {
      // let #(s, w, rumors, topology, algorithm, neighbor_list) = state.internal

      process.send(
        client,
        InternalStateGossip(State(state.internal, [], [], [])),
      )
      actor.continue(state)
    }
    GetInternalPushSum(client) -> {
      // let #(s, w, rumors, topology, algorithm, neighbor_list) = state.internal

      process.send(
        client,
        InternalStatePushSum(State(state.internal, [], [], []), client),
      )
      actor.continue(state)
    }

    // Push(value) -> {
    //   actor.continue(State(state.internal, [value, ..state.stack]))
    // }
    InternalStateGossip(sent_state) -> {
      let #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = sent_state.internal

      let total_actors = number_of_nodes

      let total_rumors = [rumors, ..state.stack]

      let total_rumors_length = list.length(total_rumors)

      case total_rumors_length == total_actors {
        True -> {
          // io.println("Full List")
          let check = case list.all(total_rumors, fn(x) { x > 0 }) {
            True -> 1
            False -> 0
          }

          case check == 1 {
            True -> {
              //Done, All rumors heard
              // io.println("Done")

              let later = timestamp.system_time()

              // io.println("Hi")
              let time_later_ms = timestamp.to_unix_seconds(later)
              echo time_later_ms -. initial_time

              actor.continue(State(state.internal, [], [], []))
            }
            False -> {
              //Not all rumors heard, try again
              actor.continue(State(state.internal, [], [], []))
            }
          }
        }
        //Continue accumulating actor states
        False -> actor.continue(State(state.internal, total_rumors, [], []))
      }
      // actor.continue(State(state.internal, total_rumors))
    }
    InternalStatePushSum(sent_state, client) -> {
      let #(
        s,
        w,
        rumors,
        topology,
        algorithm,
        neighbor_list,
        number_of_nodes,
        initial_time,
        actor_id,
        all_actors,
        terminated_list,
        terminated_neighbor_list,
        not_terminated_neighbors,
        start_s,
        start_w,
      ) = sent_state.internal

      actor.continue(state)
    }
    // PopGossip(client) ->
    //   case state.stack {
    //     [] -> {
    //       process.send(client, Error(Nil))
    //       actor.continue(state)
    //     }
    //     [first, ..rest] -> {
    //       process.send(client, Ok(first))
    //       actor.continue(State(state.internal, rest))
    //     }
    //   }
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

  let initial_s = 1.0
  let initial_w = 1.0

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

  // full, 3D, line, or imp3D default
  // let topology_number = case topology {
  //   "full" -> "full"
  //   "3D" -> "3D"
  //   "line" -> "line"
  //   "imp3D" -> "imp3D"
  //   _ -> "full"
  // }

  //Set number_of_nodes, in case it is cube
  let number_of_nodes = case topology {
    "full" -> number_of_nodes
    "3D" -> {
      let base_list = list.range(0, number_of_nodes - 1)

      let cube_list = list.map(base_list, fn(n) { n * n * n })

      let number_of_nodes = case
        list.find(cube_list, fn(n) { number_of_nodes <= n })
      {
        Ok(number_of_nodes) -> number_of_nodes
        Error(_) -> 0
      }
      number_of_nodes
    }
    "line" -> number_of_nodes
    "imp3D" -> {
      let base_list = list.range(0, number_of_nodes - 1)

      let cube_list = list.map(base_list, fn(n) { n * n * n })

      let number_of_nodes = case
        list.find(cube_list, fn(n) { number_of_nodes <= n })
      {
        Ok(number_of_nodes) -> number_of_nodes
        Error(_) -> 0
      }
      number_of_nodes
    }
    _ -> 0
  }

  let task = list.range(0, number_of_nodes - 1)

  let assert Ok(default_actor) =
    actor.new(
      State(
        #(
          initial_s,
          initial_w,
          0,
          topology,
          algorithm,
          [],
          0,
          0.0,
          -1,
          [],
          [],
          [],
          [],
          initial_s,
          initial_w,
        ),
        [],
        [],
        [],
      ),
    )
    |> actor.on_message(handle_message)
    |> actor.start

  let line_or_full_actor_list =
    list.map(task, fn(n) {
      let assert Ok(started) =
        actor.new(
          State(
            #(
              initial_s,
              initial_w,
              0,
              topology,
              algorithm,
              [],
              number_of_nodes,
              0.0,
              n,
              [],
              [],
              [],
              [],
              initial_s,
              initial_w,
            ),
            [],
            [],
            [],
          ),
        )
        |> actor.on_message(handle_message)
        |> actor.start

      #(n, started.data, 0, 0, 0)
    })

  let base = cube_rt(number_of_nodes)

  let now = timestamp.system_time()
  let time_now_ms = timestamp.to_unix_seconds(now)

  let three_d =
    cube_coords(
      base,
      topology,
      algorithm,
      initial_s,
      initial_w,
      number_of_nodes,
      time_now_ms,
      [],
    )

  let actor_list = case topology {
    "full" -> line_or_full_actor_list
    "3D" -> three_d
    "line" -> line_or_full_actor_list
    "imp3D" -> three_d
    _ -> line_or_full_actor_list
  }

  let assert Ok(central_actor) =
    actor.new(
      State(
        #(
          initial_s,
          initial_w,
          0,
          topology,
          algorithm,
          [],
          number_of_nodes,
          0.0,
          -2,
          actor_list,
          [],
          [],
          [],
          initial_s,
          initial_w,
        ),
        [],
        [],
        [],
      ),
    )
    |> actor.on_message(handle_message)
    |> actor.start

  let default_placeholder = #(0, default_actor.data, 0, 0, 0)

  set_up_topology(
    actor_list,
    number_of_nodes,
    topology,
    algorithm,
    default_placeholder,
    initial_s,
    initial_w,
    time_now_ms,
  )

  // process.sleep(2000)

  process.sleep(1000)

  case algorithm {
    "gossip" ->
      start_gossip(actor_list, central_actor.data, default_placeholder)
    "push-sum" ->
      start_pushsum(actor_list, central_actor.data, default_placeholder)
    _ -> start_pushsum(actor_list, central_actor.data, default_placeholder)
  }

  process.sleep(5000)
}

fn start_gossip(actor_list, central_actor, default_placeholder) {
  let result = nth_actor(actor_list, 0)

  let #(v1, initial_actor, v2, v3, v4) = case result {
    Ok(result) -> result
    Error(_) -> default_placeholder
  }

  //Start With one actor, actor 0
  process.send(initial_actor, SendRumor)

  step_actors_gossip(actor_list, central_actor, 1)
}

//TODO Need to create a separate message that is a start message

fn start_pushsum(actor_list, central_actor, default_placeholder) {
  let result = nth_actor(actor_list, 0)

  let #(v1, initial_actor, v2, v3, v4) = case result {
    Ok(result) -> result
    Error(_) -> default_placeholder
  }

  //todo Start With one actor, actor 0
  process.send(initial_actor, SendPushSum(1.0, 1.0))

  step_actors_pushsum(actor_list, central_actor, 1)
}

fn step_actors_gossip(actor_list, central_actor, step) {
  // process.sleep(1000)
  case step % 5 == 0 {
    True -> {
      get_internal_gossip(actor_list, central_actor)
      step_actors_gossip(actor_list, central_actor, step + 1)
    }
    False -> {
      list.each(actor_list, fn(actor_tuple) {
        let #(v1, actor, v2, v3, v4) = actor_tuple
        process.send(actor, StepGossip)
      })

      step_actors_gossip(actor_list, central_actor, step + 1)
    }
  }
}

fn step_actors_pushsum(actor_list, central_actor, step) {
  process.sleep(10)
  case step % 5 == 0 {
    True -> {
      get_internal_pushsum(actor_list, central_actor)
      step_actors_pushsum(actor_list, central_actor, step + 1)
    }
    False -> {
      list.each(actor_list, fn(actor_tuple) {
        let #(v1, actor, v2, v3, v4) = actor_tuple
        process.send(actor, StepPushSum(central_actor))
      })

      step_actors_pushsum(actor_list, central_actor, step + 1)
    }
  }
}

fn get_internal_gossip(actor_list, central_actor) {
  list.each(actor_list, fn(actor_tuple) {
    let #(v1, actor, v2, v3, v4) = actor_tuple
    process.send(actor, GetInternalGossip(central_actor))
  })
}

fn get_internal_pushsum(actor_list, central_actor) {
  list.each(actor_list, fn(actor_tuple) {
    let #(v1, actor, v2, v3, v4) = actor_tuple
    process.send(actor, GetInternalPushSum(central_actor))
  })
}

pub fn extract_ids(
  inputs: List(#(Int, process.Subject(Message), Int, Int, Int)),
) -> List(Int) {
  list.map(inputs, fn(tuple) {
    let #(id, _subject, _x, _y, _z) = tuple
    id
  })
}

pub fn intersect(a: List(Int), b: List(Int)) -> List(Int) {
  list.filter(a, fn(x) { list.contains(b, x) })
}

pub fn filter_not_in(
  a: List(#(Int, process.Subject(Message), Int, Int, Int)),
  b: List(Int),
) -> List(#(Int, process.Subject(Message), Int, Int, Int)) {
  list.filter(a, fn(t) {
    let #(id, _subject, _x, _y, _z) = t
    case list.find(b, fn(bv) { bv == id }) {
      Ok(_) -> False
      // id is in b → filter out
      Error(_) -> True
      // id not in b → keep
    }
  })
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
  xs: List(#(Int, process.Subject(Message), Int, Int, Int)),
  i: Int,
) -> Result(#(Int, process.Subject(Message), Int, Int, Int), Nil) {
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

pub fn nth_actor_coordinates(
  xs: List(#(Int, process.Subject(Message), Int, Int, Int)),
  x1: Int,
  y1: Int,
  z1: Int,
) -> Result(#(Int, process.Subject(Message), Int, Int, Int), Nil) {
  case xs {
    [] -> Error(Nil)

    [#(id, subj, x, y, z), ..rest] ->
      case x == x1 && y == y1 && z == z1 {
        True -> Ok(#(id, subj, x, y, z))
        False -> nth_actor_coordinates(rest, x1, y1, z1)
      }
  }
}

pub fn nth_ratio_id(xs: List(#(Int, Float)), id1: Int) -> #(Int, Float) {
  case xs {
    [] -> #(0, 0.0)

    [#(id, ratio), ..rest] ->
      case id1 == id {
        True -> #(id, ratio)
        False -> nth_ratio_id(rest, id1)
      }
  }
}

fn set_up_topology(
  actor_list,
  number_of_nodes,
  topology,
  algorithm,
  default_actor,
  initial_s,
  initial_w,
  initial_time,
) {
  case topology {
    "full" ->
      set_up_full_topology(
        actor_list,
        topology,
        algorithm,
        default_actor,
        initial_s,
        initial_w,
        number_of_nodes,
        initial_time,
      )
    "3D" ->
      set_up_three_d_topology(
        actor_list,
        topology,
        algorithm,
        default_actor,
        number_of_nodes,
        initial_s,
        initial_w,
        initial_time,
      )
    "line" ->
      set_up_line_topology(
        actor_list,
        topology,
        algorithm,
        default_actor,
        initial_s,
        initial_w,
        number_of_nodes,
        initial_time,
      )
    "imp3D" ->
      set_up_three_d_imperfect_topology(
        actor_list,
        topology,
        algorithm,
        default_actor,
        number_of_nodes,
        initial_s,
        initial_w,
        initial_time,
      )
    _ ->
      set_up_full_topology(
        actor_list,
        topology,
        algorithm,
        default_actor,
        initial_s,
        initial_w,
        number_of_nodes,
        initial_time,
      )
  }
}

fn set_up_full_topology(
  actor_list,
  topology,
  algorithm,
  default_actor,
  initial_s,
  initial_w,
  number_of_nodes,
  initial_time,
) {
  list.each(actor_list, fn(actor_tuple) {
    let #(actor_number, actor, x, y, z) = actor_tuple

    let neighbor_list_length = list.length(actor_list) - 1

    let neighbor_list = list.range(0, neighbor_list_length - 1)

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

        filtered_actor
      })
    //Set the internal state with updated topology neighbors

    let initial_s = int.to_float({ actor_number % 10 } + 1)

    let internal_state = #(
      initial_s,
      initial_w,
      0,
      topology,
      algorithm,
      neighbor_list,
      number_of_nodes,
      initial_time,
      actor_number,
      actor_list,
      [],
      [],
      neighbor_list,
      initial_s,
      initial_w,
    )
    process.send(actor, SetInternal(internal_state))
  })
}

fn set_up_line_topology(
  actor_list,
  topology,
  algorithm,
  default_actor,
  initial_s,
  initial_w,
  number_of_nodes,
  initial_time,
) {
  list.each(actor_list, fn(actor_tuple) {
    let #(actor_number, actor, x, y, z) = actor_tuple

    let end_actor = list.length(actor_list) - 1

    let neighbor_list = case actor_number == 0 {
      True -> list.range(0, 0)
      False ->
        case actor_number == end_actor {
          True -> list.range(0, 0)
          False -> list.range(0, 1)
        }
    }

    let neighbor_list =
      list.map(neighbor_list, fn(n) {
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

        filtered_actor
      })
    //Set the internal state with updated topology neighbors

    let initial_s = int.to_float({ actor_number % 10 } + 1)

    let internal_state = #(
      initial_s,
      initial_w,
      0,
      topology,
      algorithm,
      neighbor_list,
      number_of_nodes,
      initial_time,
      actor_number,
      actor_list,
      [],
      [],
      neighbor_list,
      initial_s,
      initial_w,
    )
    process.send(actor, SetInternal(internal_state))
  })
}

fn set_up_three_d_topology(
  actor_list,
  topology,
  algorithm,
  default_actor,
  cube,
  initial_s,
  initial_w,
  initial_time,
) {
  let base = cube_rt(cube)

  list.each(actor_list, fn(actor_tuple) {
    let #(actor_number, actor, x, y, z) = actor_tuple

    //Corner Case first
    let neighbor_list = case
      { x == 0 && y == 0 && z == 0 }
      || { x == base - 1 && y == 0 && z == 0 }
      || { x == 0 && y == base - 1 && z == 0 }
      || { x == base - 1 && y == base - 1 && z == 0 }
      || { x == 0 && y == 0 && z == base - 1 }
      || { x == base - 1 && y == 0 && z == base - 1 }
      || { x == 0 && y == base - 1 && z == base - 1 }
      || { x == base - 1 && y == base - 1 && z == base - 1 }
    {
      //Edges Case second
      True -> {
        list.range(0, 2)
      }
      False ->
        case
          { x > 0 && x < base - 1 && y == 0 && z == 0 }
          || { x > 0 && x < base - 1 && y == base - 1 && z == 0 }
          || { y > 0 && y < base - 1 && x == 0 && z == 0 }
          || { y > 0 && y < base - 1 && x == base - 1 && z == 0 }
          || { x > 0 && x < base - 1 && y == 0 && z == base - 1 }
          || { x > 0 && x < base - 1 && y == base - 1 && z == base - 1 }
          || { y > 0 && y < base - 1 && x == 0 && z == base - 1 }
          || { y > 0 && y < base - 1 && x == base - 1 && z == base - 1 }
          || { z > 0 && z < base - 1 && x == 0 && y == 0 }
          || { z > 0 && z < base - 1 && x == 0 && y == base - 1 }
          || { z > 0 && z < base - 1 && x == base - 1 && y == 0 }
          || { z > 0 && z < base - 1 && x == base - 1 && y == base - 1 }
        {
          //Face Cases third
          True -> list.range(0, 3)
          False ->
            case
              { y > 0 && y < base - 1 && x == 0 && z > 0 && z < base - 1 }
              || {
                y > 0 && y < base - 1 && x == base - 1 && z > 0 && z < base - 1
              }
              || { x > 0 && x < base - 1 && y == 0 && z > 0 && z < base - 1 }
              || {
                x > 0 && x < base - 1 && y == base - 1 && z > 0 && z < base - 1
              }
              || { x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == 0 }
              || {
                x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == base - 1
              }
            {
              //Center case fourth
              True -> list.range(0, 4)
              False ->
                case
                  {
                    x > 0
                    && x < base - 1
                    && y > 0
                    && y < base - 1
                    && z > 0
                    && z < base - 1
                  }
                {
                  True -> list.range(0, 5)
                  False -> list.range(0, 0)
                }
            }
        }
    }

    let output =
      apply_mapping(
        neighbor_list,
        actor_list,
        default_actor,
        x,
        y,
        z,
        get_actor,
        base,
      )

    let initial_s = int.to_float({ actor_number % 10 } + 1)

    let internal_state = #(
      initial_s,
      initial_w,
      0,
      topology,
      algorithm,
      output,
      cube,
      initial_time,
      actor_number,
      actor_list,
      [],
      [],
      output,
      initial_s,
      initial_w,
    )
    process.send(actor, SetInternal(internal_state))
  })
}

fn set_up_three_d_imperfect_topology(
  actor_list,
  topology,
  algorithm,
  default_actor,
  cube,
  initial_s,
  initial_w,
  initial_time,
) {
  let base = cube_rt(cube)

  list.each(actor_list, fn(actor_tuple) {
    let #(actor_number, actor, x, y, z) = actor_tuple

    //Corner Case first
    let neighbor_list = case
      { x == 0 && y == 0 && z == 0 }
      || { x == base - 1 && y == 0 && z == 0 }
      || { x == 0 && y == base - 1 && z == 0 }
      || { x == base - 1 && y == base - 1 && z == 0 }
      || { x == 0 && y == 0 && z == base - 1 }
      || { x == base - 1 && y == 0 && z == base - 1 }
      || { x == 0 && y == base - 1 && z == base - 1 }
      || { x == base - 1 && y == base - 1 && z == base - 1 }
    {
      //Edges Case second
      True -> {
        list.range(0, 3)
      }
      False ->
        case
          { x > 0 && x < base - 1 && y == 0 && z == 0 }
          || { x > 0 && x < base - 1 && y == base - 1 && z == 0 }
          || { y > 0 && y < base - 1 && x == 0 && z == 0 }
          || { y > 0 && y < base - 1 && x == base - 1 && z == 0 }
          || { x > 0 && x < base - 1 && y == 0 && z == base - 1 }
          || { x > 0 && x < base - 1 && y == base - 1 && z == base - 1 }
          || { y > 0 && y < base - 1 && x == 0 && z == base - 1 }
          || { y > 0 && y < base - 1 && x == base - 1 && z == base - 1 }
          || { z > 0 && z < base - 1 && x == 0 && y == 0 }
          || { z > 0 && z < base - 1 && x == 0 && y == base - 1 }
          || { z > 0 && z < base - 1 && x == base - 1 && y == 0 }
          || { z > 0 && z < base - 1 && x == base - 1 && y == base - 1 }
        {
          //Face Cases third
          True -> list.range(0, 4)
          False ->
            case
              { y > 0 && y < base - 1 && x == 0 && z > 0 && z < base - 1 }
              || {
                y > 0 && y < base - 1 && x == base - 1 && z > 0 && z < base - 1
              }
              || { x > 0 && x < base - 1 && y == 0 && z > 0 && z < base - 1 }
              || {
                x > 0 && x < base - 1 && y == base - 1 && z > 0 && z < base - 1
              }
              || { x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == 0 }
              || {
                x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == base - 1
              }
            {
              //Center case fourth
              True -> list.range(0, 5)
              False ->
                case
                  {
                    x > 0
                    && x < base - 1
                    && y > 0
                    && y < base - 1
                    && z > 0
                    && z < base - 1
                  }
                {
                  True -> list.range(0, 6)
                  False -> list.range(0, 0)
                }
            }
        }
    }

    let output =
      apply_mapping(
        neighbor_list,
        actor_list,
        default_actor,
        x,
        y,
        z,
        get_actor,
        base,
      )

    let initial_s = int.to_float({ actor_number % 10 } + 1)

    let internal_state = #(
      initial_s,
      initial_w,
      0,
      topology,
      algorithm,
      output,
      cube,
      initial_time,
      actor_number,
      actor_list,
      [],
      [],
      output,
      initial_s,
      initial_w,
    )
    process.send(actor, SetInternal(internal_state))
  })
}

@external(erlang, "erlang", "trunc")
pub fn float_to_int(x: Float) -> Int

fn cube_rt(number) {
  let cubed_root = case
    int.power(number, 0.3333333333333333333333333333333333333333)
  {
    Ok(cubed_root) -> cubed_root
    Error(_) -> 0.0
  }
  //Round to nearest number, should be correct
  let cubed_root = float.ceiling(cubed_root)

  let base = float_to_int(cubed_root)
  base
}

pub fn cube_coords(
  n: Int,
  topology,
  algorithm,
  initial_s,
  initial_w,
  number_of_nodes,
  initial_time,
  actor_list,
) -> List(#(Int, process.Subject(Message), Int, Int, Int)) {
  let count = 0
  list.flat_map(list.range(0, n - 1), fn(z) {
    list.flat_map(list.range(0, n - 1), fn(y) {
      list.map(list.range(0, n - 1), fn(x) {
        let assert Ok(started) =
          actor.new(
            State(
              #(
                initial_s,
                initial_w,
                0,
                topology,
                algorithm,
                [],
                number_of_nodes,
                initial_time,
                count,
                actor_list,
                [],
                [],
                [],
                initial_s,
                initial_w,
              ),
              [],
              [],
              [],
            ),
          )
          |> actor.on_message(handle_message)
          |> actor.start

        let count = { n * n } * z + { n } * y + x

        #(count, started.data, x, y, z)
      })
    })
  })
}

pub fn get_actor(actor_list, default_actor, x, y, z) {
  let result = nth_actor_coordinates(actor_list, x, y, z)

  let result = case result {
    Ok(result) -> result
    Error(_) -> default_actor
  }
  result
}

pub fn rules(base) -> List(Rule) {
  [
    // corner at (0,0,0)
    #(fn(x, y, z) { x == 0 && y == 0 && z == 0 }, corner1_map),
    #(fn(x, y, z) { x == base - 1 && y == 0 && z == 0 }, corner2_map),
    #(fn(x, y, z) { x == 0 && y == base - 1 && z == 0 }, corner3_map),
    #(fn(x, y, z) { x == base - 1 && y == base - 1 && z == 0 }, corner4_map),
    #(fn(x, y, z) { x == 0 && y == 0 && z == base - 1 }, corner5_map),
    #(fn(x, y, z) { x == base - 1 && y == 0 && z == base - 1 }, corner6_map),
    #(fn(x, y, z) { x == 0 && y == base - 1 && z == base - 1 }, corner7_map),
    #(
      fn(x, y, z) { x == base - 1 && y == base - 1 && z == base - 1 },
      corner8_map,
    ),
    #(fn(x, y, z) { x > 0 && x < base - 1 && y == 0 && z == 0 }, edge1_map),
    #(
      fn(x, y, z) { x > 0 && x < base - 1 && y == base - 1 && z == 0 },
      edge2_map,
    ),
    #(fn(x, y, z) { y > 0 && y < base - 1 && x == 0 && z == 0 }, edge3_map),
    #(
      fn(x, y, z) { y > 0 && y < base - 1 && x == base - 1 && z == 0 },
      edge4_map,
    ),
    #(
      fn(x, y, z) { x > 0 && x < base - 1 && y == 0 && z == base - 1 },
      edge5_map,
    ),
    #(
      fn(x, y, z) { x > 0 && x < base - 1 && y == base - 1 && z == base - 1 },
      edge6_map,
    ),
    #(
      fn(x, y, z) { y > 0 && y < base - 1 && x == 0 && z == base - 1 },
      edge7_map,
    ),
    #(
      fn(x, y, z) { y > 0 && y < base - 1 && x == base - 1 && z == base - 1 },
      edge8_map,
    ),
    #(fn(x, y, z) { z > 0 && z < base - 1 && x == 0 && y == 0 }, edge9_map),
    #(
      fn(x, y, z) { z > 0 && z < base - 1 && x == 0 && y == base - 1 },
      edge10_map,
    ),
    #(
      fn(x, y, z) { z > 0 && z < base - 1 && x == base - 1 && y == 0 },
      edge11_map,
    ),
    #(
      fn(x, y, z) { z > 0 && z < base - 1 && x == base - 1 && y == base - 1 },
      edge12_map,
    ),
    #(
      fn(x, y, z) { y > 0 && y < base - 1 && x == 0 && z > 0 && z < base - 1 },
      face1_map,
    ),
    #(
      fn(x, y, z) {
        y > 0 && y < base - 1 && x == base - 1 && z > 0 && z < base - 1
      },
      face2_map,
    ),
    #(
      fn(x, y, z) { x > 0 && x < base - 1 && y == 0 && z > 0 && z < base - 1 },
      face3_map,
    ),
    #(
      fn(x, y, z) {
        x > 0 && x < base - 1 && y == base - 1 && z > 0 && z < base - 1
      },
      face4_map,
    ),
    #(
      fn(x, y, z) { x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == 0 },
      face5_map,
    ),
    #(
      fn(x, y, z) {
        x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == base - 1
      },
      face6_map,
    ),
    #(
      fn(x, y, z) {
        x > 0 && x < base - 1 && y > 0 && y < base - 1 && z > 0 && z < base - 1
      },
      center_map,
    ),
  ]
}

pub fn pick_mapper(
  base: Int,
  x: Int,
  y: Int,
  z: Int,
) -> fn(Int, Int, Int, Int, Int) -> #(Int, Int, Int) {
  case
    list.find(rules(base), fn(rule) {
      let #(pred, _mapper) = rule
      pred(x, y, z)
    })
  {
    Ok(#(_, mapper)) -> mapper
    Error(_) -> fn(_n: Int, x: Int, y: Int, z: Int, base: Int) { #(x, y, z) }
    // identity fallback
  }
}

pub fn apply_mapping(
  neighbor_list: List(Int),
  actor_list: List(a),
  default_actor: a,
  x: Int,
  y: Int,
  z: Int,
  get_actor: fn(List(a), a, Int, Int, Int) -> a,
  base: Int,
) -> List(a) {
  // Pick the correct mapper based on the current x,y,z
  let mapper = pick_mapper(base, x, y, z)

  // Map each neighbor index to an actor using the mapper
  list.map(neighbor_list, fn(n) {
    let #(nx, ny, nz) = mapper(n, x, y, z, base)
    get_actor(actor_list, default_actor, nx, ny, nz)
  })
}

fn corner1_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x + 1, y, z)
    1 -> #(x, y + 1, z)
    2 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn corner2_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x, y + 1, z)
    2 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn corner3_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn corner4_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x - 1, y, z)
    2 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn corner5_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y + 1, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn corner6_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x, y + 1, z)
    2 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn corner7_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn corner8_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x - 1, y, z)
    2 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

// ---------- Edge Maps ----------
fn edge1_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y + 1, z)
    3 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge2_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y - 1, z)
    3 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge3_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x, y + 1, z)
    2 -> #(x + 1, y, z)
    3 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge4_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x, y + 1, z)
    2 -> #(x - 1, y, z)
    3 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge5_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x + 1, y, z)
    1 -> #(x - 1, y, z)
    2 -> #(x, y + 1, z)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge6_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x + 1, y, z)
    1 -> #(x - 1, y, z)
    2 -> #(x, y - 1, z)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge7_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x, y + 1, z)
    2 -> #(x + 1, y, z)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge8_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x, y + 1, z)
    2 -> #(x, y - 1, z)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge9_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x + 1, y, z)
    1 -> #(x, y + 1, z)
    2 -> #(x, y, z + 1)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

// ---------- Edge Maps (continued) ----------
fn edge10_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x + 1, y, z)
    1 -> #(x, y - 1, z)
    2 -> #(x, y, z + 1)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge11_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x, y + 1, z)
    2 -> #(x, y, z + 1)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn edge12_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x, y - 1, z)
    2 -> #(x, y, z + 1)
    3 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

// ---------- Face Maps ----------
fn face1_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x, y + 1, z)
    2 -> #(x + 1, y, z)
    3 -> #(x, y, z - 1)
    4 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn face2_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x, y + 1, z)
    2 -> #(x - 1, y, z)
    3 -> #(x, y, z - 1)
    4 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn face3_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y + 1, z)
    1 -> #(x - 1, y, z)
    2 -> #(x + 1, y, z)
    3 -> #(x, y, z - 1)
    4 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn face4_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x, y - 1, z)
    1 -> #(x - 1, y, z)
    2 -> #(x + 1, y, z)
    3 -> #(x, y, z - 1)
    4 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn face5_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y - 1, z)
    3 -> #(x, y + 1, z)
    4 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

fn face6_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)
  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y - 1, z)
    3 -> #(x, y + 1, z)
    4 -> #(x, y, z - 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}

// ---------- Center Map ----------
fn center_map(n: Int, x: Int, y: Int, z: Int, base: Int) -> #(Int, Int, Int) {
  let rand_x = int.random(base)
  let rand_y = int.random(base)
  let rand_z = int.random(base)

  case n {
    0 -> #(x - 1, y, z)
    1 -> #(x + 1, y, z)
    2 -> #(x, y - 1, z)
    3 -> #(x, y + 1, z)
    4 -> #(x, y, z - 1)
    5 -> #(x, y, z + 1)
    _ -> #(rand_x, rand_y, rand_z)
  }
}
