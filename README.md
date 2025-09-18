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

## Development

```sh
gleam run numNodes topology algorithm   # Run the project
# gleam run 100 full gossip

gleam test  # Run the tests
```
## Team Members
- Andrew Rippy
- B Sri Vaishnavi

## What is Working
- Implementation of Gossip and Push-Sum algorithms.
- Convergence time measurements for various topologies.
  - Full topology
  - Line topology
  - 3D topology
  - imp3D topology

## Largest Network Size
- Successfully managed up to 400 nodes for each type of topology and algorithm.
