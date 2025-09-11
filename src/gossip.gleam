import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

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
    ),
    stack: List(String),
  )
}

// ----- Messages the actor understands -----
pub type Message {
  Shutdown
  SetInternal(
    #(
      Float,
      Float,
      Int,
      String,
      String,
      List(#(Int, process.Subject(Message), Int, Int, Int)),
    ),
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

  // echo task

  let assert Ok(default_actor) =
    actor.new(State(#(0.0, 0.0, 0, topology, algorithm, []), []))
    |> actor.on_message(handle_message)
    |> actor.start

  let line_or_full_actor_list =
    list.map(task, fn(n) {
      let assert Ok(started) =
        actor.new(State(#(0.0, 0.0, 0, topology, algorithm, []), []))
        |> actor.on_message(handle_message)
        |> actor.start

      #(n, started.data, 0, 0, 0)
    })

  let base = cube_rt(number_of_nodes)

  // let y_list = list.range(0, cubed_root)

  // let coordinates = list.range(0, base - 1)
  // echo coordinates

  // let mapping =
  //   list.map(coordinates, fn(z) {
  //     list.map(coordinates, fn(y) {
  //       list.map(coordinates, fn(x) { #(x, y, z) })
  //     })
  //   })

  // echo mapping

  let three_d = cube_coords(base, topology, algorithm)
  // echo three_d
  // echo line_or_full_actor_list

  let actor_list = case topology {
    "full" -> line_or_full_actor_list
    "3D" -> three_d
    "line" -> line_or_full_actor_list
    "imp3D" -> three_d
    _ -> line_or_full_actor_list
  }

  // echo actor_list

  // let coordinate_mapping = list.map(task, fn(n){

  // })
  let default_placeholder = #(0, default_actor.data, 0, 0, 0)

  set_up_topology(
    actor_list,
    number_of_nodes,
    topology,
    algorithm,
    default_placeholder,
  )

  process.sleep(2000)

  // list.each(actor_list, fn(actor_tuple) {
  //   let #(actor_number, actor, x, y, z) = actor_tuple

  //   process.send(actor, Push("Alice"))
  // })
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

fn set_up_topology(
  actor_list,
  number_of_nodes,
  topology,
  algorithm,
  default_actor,
) {
  // echo 1
  // case topology {
  //   "full" -> "full"
  //   "3D" -> "3D"
  //   "line" -> "line"
  //   "imp3D" -> "imp3D"
  //   _ -> "full"
  // }

  // set_up_full_topology(actor_list, topology, algorithm, default_actor)
  // set_up_line_topology(actor_list, topology, algorithm, default_actor)
  set_up_three_d_topology(
    actor_list,
    topology,
    algorithm,
    default_actor,
    number_of_nodes,
  )
  // let rand_x = int.random(base)
  // let rand_y = int.random(base)
  // let rand_z = int.random(base)

  // echo rand
  // let test1 = #(1, 2, 2)
  // let test2 = #(1, 2, 2)
  // echo test1 == 
  // let result = nth_actor_coordinates(actor_list, 1, 1, 1)

  // echo result
}

fn set_up_full_topology(actor_list, topology, algorithm, default_actor) {
  // echo actor_list

  list.each(actor_list, fn(actor_tuple) {
    // let hi = #(0.0, 0.0, 0, topology, algorithm, actor_list)
    // process.send(actor, SetInternal(hi))

    let #(actor_number, actor, x, y, z) = actor_tuple

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
    // echo neighbor_list
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

    let #(actor_number, actor, x, y, z) = actor_tuple

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

fn set_up_three_d_topology(actor_list, topology, algorithm, default_actor, cube) {
  // echo actor_list

  // let cubed_root = case
  //   int.power(cube, 0.3333333333333333333333333333333333333333)
  // {
  //   Ok(cubed_root) -> cubed_root
  //   Error(_) -> 0.0
  // }
  // // echo cubed_root
  // //Round to nearest number, should be correct
  // let cubed_root = float.ceiling(cubed_root)
  // echo cubed_root
  let base = cube_rt(cube)

  // let square = base * base
  // echo base
  // echo square
  // echo cube

  // let phase1 = list.range(0, base - 1)

  list.each(actor_list, fn(actor_tuple) {
    // let hi = #(0.0, 0.0, 0, topology, algorithm, actor_list)
    // process.send(actor, SetInternal(hi))

    let #(actor_number, actor, x, y, z) = actor_tuple
    //Corner Cases
    // let neighbor_list = case
    //   { x == 0 && y == 0 && z == 0 }
    //   || { x == base - 1 && y == 0 && z == 0 }
    //   || { x == 0 && y == base - 1 && z == 0 }
    //   || { x == base - 1 && y == base - 1 && z == 0 }
    //   || { x == 0 && y == 0 && z == base - 1 }
    //   || { x == base - 1 && y == 0 && z == base - 1 }
    //   || { x == 0 && y == base - 1 && z == base - 1 }
    //   || { x == base - 1 && y == base - 1 && z == base - 1 }
    // {
    //   True -> list.range(0, 2)
    //   False -> list.range(0, 0)
    // }

    //Edges Cases
    // let neighbor_list = case
    //   { x > 0 && x < base - 1 && y == 0 && z == 0 }
    //   || { x > 0 && x < base - 1 && y == base - 1 && z == 0 }
    //   || { y > 0 && y < base - 1 && x == 0 && z == 0 }
    //   || { y > 0 && y < base - 1 && x == base - 1 && z == 0 }
    //   || { x > 0 && x < base - 1 && y == 0 && z == base - 1 }
    //   || { x > 0 && x < base - 1 && y == base - 1 && z == base - 1 }
    //   || { y > 0 && y < base - 1 && x == 0 && z == base - 1 }
    //   || { y > 0 && y < base - 1 && x == base - 1 && z == base - 1 }
    //   || { z > 0 && z < base - 1 && x == 0 && y == 0 }
    //   || { z > 0 && z < base - 1 && x == 0 && y == base - 1 }
    //   || { z > 0 && z < base - 1 && x == base - 1 && y == 0 }
    //   || { z > 0 && z < base - 1 && x == base - 1 && y == base - 1 }
    // {
    //   True -> list.range(0, 3)
    //   False -> list.range(0, 0)
    // }

    //Face Cases
    // let neighbor_list = case
    //   { y > 0 && y < base - 1 && x == 0 && z > 0 && z < base - 1 }
    //   || { y > 0 && y < base - 1 && x == base - 1 && z > 0 && z < base - 1 }
    //   || { x > 0 && x < base - 1 && y == 0 && z > 0 && z < base - 1 }
    //   || { x > 0 && x < base - 1 && y == base - 1 && z > 0 && z < base - 1 }
    //   || { x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == 0 }
    //   || { x > 0 && x < base - 1 && y > 0 && y < base - 1 && z == base - 1 }
    // {
    //   True -> list.range(0, 4)
    //   False -> list.range(0, 0)
    // }

    // let neighbor_list = case
    //   {
    //     x > 0 && x < base - 1 && y > 0 && y < base - 1 && z > 0 && z < base - 1
    //   }
    // {
    //   True -> list.range(0, 5)
    //   False -> list.range(0, 0)
    // }
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

    let default_actor_list = list.range(0, 0)
    let default_actor_list =
      list.map(default_actor_list, fn(n) { default_actor })
    // let output = get_actor(actor_list, default_actor, 1, 1, 1)
    // echo output
    // let result = nth_actor_coordinates(actor_list, 1, 1, 1)

    // let result = case result {
    //   Ok(result) -> result
    //   Error(_) -> default_actor
    // }
    // echo result

    // echo neighbor_list
    // let actor_output = case { x == 0 && y == 0 && z == 0 } {

    // neighbor_list: List(Int),
    //   actor_list: List(a),
    //   default_actor: a,
    //   x: Int,
    //   y: Int,
    //   z: Int,
    //   get_actor: fn(List(a), a, Int, Int, Int) -> a,

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

    let internal_state = #(0.0, 0.0, 0, topology, algorithm, output)
    process.send(actor, SetInternal(internal_state))
    // output
    // echo #(x, y, z)
    // echo output
    // echo actor_output

    // case actor_number {
    //   1 -> "one"
    //   2 -> "two"
    //   base -> "something else: " <> int.to_string(n)
    // }
    // let end_actor = list.length(actor_list) - 1

    // // echo actor_number
    // // echo end_actor
    // echo base
    // echo square
    // echo cube

    //Corner Case
    // let neighbor_list = case
    //   actor_number == 0
    //   || actor_number == base - 1
    //   || actor_number == square - base
    //   || actor_number == square - 1
    //   || actor_number == square * { base - 1 }
    //   || actor_number == square * { base - 1 } + { base - 1 }
    //   || actor_number == cube - base
    //   || actor_number == cube - 1
    // {
    //   //Corner
    //   True -> list.range(0, 2)
    //   False -> list.range(0, 0)
    // }

    // echo actor_number
    // echo neighbor_list

    // let neighbor_list = case {
    //   True -> list.range(0, 4)
    //   False -> list.range(0, 0)
    // }
  })
  // let neighbor_list = case actor_number == 0 {
  //   True -> list.range(0, 0)
  //   False ->
  //     case actor_number == end_actor {
  //       True -> list.range(0, 0)
  //       False -> list.range(0, 1)
  //     }
  // }

  // echo neighbor_list
  // let test_subject = process.new_subject(Message)

  // let first_actor = case nth_actor(actor_list, 0) {
  //   Ok(arg) -> arg
  //   Error(_) -> default_actor
  // }

  // list.map(neighbor_list, fn(n){
  // let offset = 0
  // let neighbor_list =
  //   list.map(neighbor_list, fn(n) {
  //     n
  //     // let offset = case n >= actor_number {
  //     //   True -> 1
  //     //   False -> 0
  //     // }

  //     // index
  //     // let filtered_actor = case nth_actor(actor_list, index) {
  //     //   Ok(arg) -> arg
  //     //   Error(_) -> default_actor
  //     // }
  //     // // echo filtered_actor

  //     // filtered_actor
  //   })
  // echo neighbor_list
  //Set the internal state with updated topology neighbors

  // let internal_state = #(0.0, 0.0, 0, topology, algorithm, neighbor_list)
  // process.send(actor, SetInternal(internal_state))
  // })
}

fn set_up_three_d_imperfect_topology(
  actor_list,
  topology,
  algorithm,
  default_actor,
  cube,
) {
  // echo actor_list

  // let cubed_root = case
  //   int.power(cube, 0.3333333333333333333333333333333333333333)
  // {
  //   Ok(cubed_root) -> cubed_root
  //   Error(_) -> 0.0
  // }
  // // echo cubed_root
  // //Round to nearest number, should be correct
  // let cubed_root = float.ceiling(cubed_root)
  // echo cubed_root
  let base = cube_rt(cube)

  // let square = base * base
  // echo base
  // echo square
  // echo cube

  // let phase1 = list.range(0, base - 1)

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

    let default_actor_list = list.range(0, 0)
    let default_actor_list =
      list.map(default_actor_list, fn(n) { default_actor })
    // let output = get_actor(actor_list, default_actor, 1, 1, 1)
    // echo output
    // let result = nth_actor_coordinates(actor_list, 1, 1, 1)

    // let result = case result {
    //   Ok(result) -> result
    //   Error(_) -> default_actor
    // }
    // echo result

    // echo neighbor_list
    // let actor_output = case { x == 0 && y == 0 && z == 0 } {

    // neighbor_list: List(Int),
    //   actor_list: List(a),
    //   default_actor: a,
    //   x: Int,
    //   y: Int,
    //   z: Int,
    //   get_actor: fn(List(a), a, Int, Int, Int) -> a,

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

    let internal_state = #(0.0, 0.0, 0, topology, algorithm, output)
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
  // echo cubed_root
  //Round to nearest number, should be correct
  let cubed_root = float.ceiling(cubed_root)

  let base = float_to_int(cubed_root)
  base
}

pub fn cube_coords(
  n: Int,
  topology,
  algorithm,
) -> List(#(Int, process.Subject(Message), Int, Int, Int)) {
  let count = 0
  list.flat_map(list.range(0, n - 1), fn(z) {
    list.flat_map(list.range(0, n - 1), fn(y) {
      list.map(list.range(0, n - 1), fn(x) {
        let assert Ok(started) =
          actor.new(State(#(0.0, 0.0, 0, topology, algorithm, []), []))
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

  // echo rand_x

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
