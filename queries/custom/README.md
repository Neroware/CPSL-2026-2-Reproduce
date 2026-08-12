# Custom GengoDB modules

Drop hand-crafted SPARQL or MLIR modules here to profile them individually
with [scripts/run-custom.sh](../../scripts/run-custom.sh) - a secondary,
lighter-weight benchmarking routine alongside the main BSBM one
(see [BENCHMARKING.md](../../BENCHMARKING.md)). **GengoDB only**: it runs
GengoDB's own `run-sparql`/`run-mlir` CLI tools directly against a DB
directory (no HTTP endpoint, no Fuseki equivalent).

- `sparql/*.sparql` (or `*.rq`) - run via `run-sparql`.
- `mlir/*.mlir` - run via `run-mlir`.

This directory is bind-mounted read-only into the `gengodb` container at
`/queries` (see `docker-compose.yml`), which is why files must live here
rather than anywhere on the host: it's the only path `run-custom.sh` can
hand to the container.

`example.sparql`/`example.mlir` are a trivial matching pair (the `.mlir`
one is what GengoDB's own `sparql-to-mlir` produces for the `.sparql` one)
kept here as a working smoke test, safe to run anytime, and a template for
other files.

## Quick start

```sh
# needs an initialized GengoDB DB directory - see BENCHMARKING.md
./scripts/init-db.sh   # if not already done

./scripts/run-custom.sh queries/custom/sparql/example.sparql
./scripts/run-custom.sh --all                     # everything in sparql/ and mlir/
./scripts/run-custom.sh --reps 10 --warmups 2 queries/custom/mlir/example.mlir
```

Results (per-file timing breakdown, averaged over the measured reps) land
in `results/custom/<run-id>/results.csv` and `results.txt`, with the raw
per-repetition tool output under `results/custom/<run-id>/logs/`.
