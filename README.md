# gossip

[![Package Version](https://img.shields.io/hexpm/v/gossip)](https://hex.pm/packages/gossip)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gossip/)



```sh
gleam add gossip@1
```
```gleam
import gossip

pub fn main() -> Nil {
  // TODO: An example of the project in use
}
```

Further documentation can be found at <https://hexdocs.pm/gossip>.
You can find the code in the [GitHub repo](https://github.com/rippy1849/dosp-project-2).

## Development

```sh
gleam run numNodes topology algorithm   # Run the project
# gleam run 100 full gossip (full, line, 3D, imp3D) (gossip, push-sum)

gleam test  # Run the tests
```
## Team Members
- Andrew Rippy
- B Sri Vaishnavi

## What is Working
- Implementation of Asynchronous Gossip algorithm for information propagation using Gleam actors.
  - Actors start with a rumor from the main process.
  - Each actor randomly selects a neighbor to share the rumor.
  - Termination occurs after hearing the rumor 10 times.
- Implementation of Push-Sum algorithm for sum computation using Gleam actors.
  - Actors maintain s and w values (initially s = i, w = 1).
  - Actors start on request and exchange (s, w) pairs with neighbors.
  - Sends half of s and w to a random neighbor, keeping the other half.
  - Estimates sum as s/w and terminates if the ratio is stable within 10⁻¹⁰ over three rounds.
- Support for multiple network topologies:
  - Full topology (all actors connected).
  - 3D Grid topology (actors connected to grid neighbors).
  - Line topology (actors in a linear sequence).
  - Imperfect 3D Grid topology (grid neighbors plus one random neighbor).
    
## Largest Network Size
- Successfully managed up to 400 nodes for each type of topology and algorithm.
