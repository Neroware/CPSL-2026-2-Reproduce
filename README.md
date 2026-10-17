# BSBM benchmarking routine

This repo runs the [Berlin SPARQL Benchmark](https://github.com/hobbit-project/BSBM)
(the pre-built Java toolkit under [tools/](tools/)) against RDF graph databases
running in Docker. Two targets are wired up, selected via `BACKEND`:

- **`gengodb`** (default) — the GengoDB project.
- **`fuseki`** — Apache Jena Fuseki, a reference/standard SPARQL implementation.

Both go through the same test-driver/orchestration scripts under
[scripts/](scripts/).

## Pieces

- [hosts/GengoDB/Dockerfile](hosts/GengoDB/Dockerfile) — builds GengoDB
  (`rz/benchmark/bsbm/latest`, release mode) and serves it via `sparql-endpoint`.
- [hosts/JenaFuseki/Dockerfile](hosts/JenaFuseki/Dockerfile) — downloads and
  verifies (SHA-512) the official Apache Jena Fuseki 6.2.0 binary
  distribution and serves it via `fuseki-server.jar` on a TDB2 dataset.
- [hosts/BSBMTools/Dockerfile](hosts/BSBMTools/Dockerfile) — a JRE image
  wrapping the pre-built `tools/lib/bsbm.jar` (dataset generator + test
  driver). Only ever used via `docker compose run`, never left running.
- [docker-compose.yml](docker-compose.yml) — defines the `gengodb`,
  `jena-fuseki` and `bsbm-tools` services on a shared network, with
  `./data` and `./results` bind-mounted in.
- [scripts/](scripts/) — the actual routine, one step per script, all
  configured through environment variables read in [scripts/lib.sh](scripts/lib.sh),
  including which backend (`BACKEND`) a given invocation targets.
- [scripts/run-custom.sh](scripts/run-custom.sh) — secondary, GengoDB-only
  routine for profiling individual hand-crafted SPARQL/MLIR modules from
  [queries/custom/](queries/custom/); see [below](#custom-module-benchmarking-gengodb-only).

## Quick start

```sh
# GengoDB (default) - needs SSH access to github.com/Neroware/GengoDB for the
# build (see hosts/GengoDB/Dockerfile) — export DOCKER_BUILDKIT=1 and have an
# ssh-agent running with the right key loaded (export SSH_AUTH_SOCK
# accordingly).
./scripts/benchmark.sh

# Jena Fuseki instead - no SSH needed, just downloads the official release.
BACKEND=fuseki ./scripts/benchmark.sh
```

This builds the images, generates a ~1,000-product BSBM dataset (shared
between backends), initializes a database directory for the selected
backend from it, starts the server, smoke-tests it, runs the BSBM "explore"
query mix, and stops the server again. Results land in
`results/<timestamp>-<scale>-<backend>/` (`result.xml`, `driver.log`,
`summary.txt`, `meta.json`).

Run the steps individually if you want to iterate without regenerating data
or reinitializing the database every time — each step is idempotent (skips
work if its output already exists; pass `FORCE=1` to redo it). Set
`BACKEND=fuseki` (or leave unset for `gengodb`) before every step:

```sh
./scripts/generate-dataset.sh          # -> data/datasets/$SCALE/ (shared)
BACKEND=fuseki ./scripts/init-db.sh    # -> data/db/$SCALE-fuseki/
BACKEND=fuseki ./scripts/serve.sh start
BACKEND=fuseki ./scripts/smoke-test.sh
BACKEND=fuseki ./scripts/run-benchmark.sh
BACKEND=fuseki ./scripts/serve.sh stop
```

To force a rebuild of the GengoDB image that actually pulls in new
upstream commits (plain `docker compose build` reuses the cached
clone/checkout/build layers indefinitely — see
[hosts/GengoDB/Dockerfile](hosts/GengoDB/Dockerfile)):

```sh
GENGODB_CACHEBUST=$(date +%s) docker compose build gengodb
```

Fuseki has no such cache-busting need — its Dockerfile pins an exact,
checksummed release ([hosts/JenaFuseki/Dockerfile](hosts/JenaFuseki/Dockerfile)),
so `docker compose build jena-fuseki` is only ever a no-op or a genuine
version bump (`--build-arg FUSEKI_VERSION=... --build-arg FUSEKI_SHA512=...`).

## Custom module benchmarking (GengoDB-only)

Alongside the full BSBM routine above, there's a second, lighter-weight
routine for profiling individual hand-crafted SPARQL or MLIR modules:
[scripts/run-custom.sh](scripts/run-custom.sh). It drives GengoDB's own
`run-sparql`/`run-mlir` CLI tools directly against an already-initialized
DB directory (no HTTP endpoint involved) and writes their profiling
output to a result table. **GengoDB-only** — those tools don't exist in
the Fuseki image and don't go through the SPARQL protocol, so `BACKEND`
is forced to `gengodb` regardless of the environment.

```sh
./scripts/init-db.sh                                    # if not already done
./scripts/run-custom.sh queries/custom/sparql/example.sparql
./scripts/run-custom.sh --all                            # everything under queries/custom/
./scripts/run-custom.sh --reps 10 --warmups 2 queries/custom/mlir/example.mlir
```

Files must live under `queries/custom/{sparql,mlir}/` (see
[queries/custom/README.md](queries/custom/README.md)) — that directory is
bind-mounted read-only into the `gengodb` container as `/queries`
(`docker-compose.yml`), which is the only path `run-custom.sh` can hand to
`run-sparql`/`run-mlir`. Drop a `.sparql`/`.rq` or `.mlir` file there and
point the script at it, or pass `--all` to run everything found.

Each file is run some number of discarded warmup repetitions
(`--warmups`, default 1) followed by measured repetitions (`--reps`,
default 5). Results land in `results/custom/<run-id>/`:

- `results.csv`/`results.txt` — one row per file: the mean of each
  compiler/execution phase GengoDB's `TimingPrinter` reports (`QOpt`,
  `lowerRelAlg`, `lowerToLLVM`, `llvmCodeGen`, `executionTime`, `total`,
  etc. — all in ms) over the successful reps, plus min/max for
  `executionTime`/`total` to gauge run-to-run noise. A file that crashes
  or errors on every rep gets a `FAILED` row instead of aborting the rest
  of the run.
- `logs/<file>.repN.log` — the raw `run-sparql`/`run-mlir` output for
  every individual repetition (query results + timing table), for
  debugging or double-checking the aggregation.
- `meta.json` — run configuration (scale, DB directory, reps, warmups,
  files, timestamp).

[scripts/parse-timing.sh](scripts/parse-timing.sh) is the piece that
turns one `run-sparql`/`run-mlir` log into a CSV line — it locates the
fixed-width timing table GengoDB prints positionally (rather than
whitespace-splitting) since several of its columns are blank whenever the
baseline backend is off (the default), which would otherwise silently
misalign a naive split. See the comments in that script and in
`run-custom.sh`'s `COLUMNS` array for the exact assumptions (tied to
`lingodb::execution::TimingPrinter` in GengoDB's
`include/lingodb/execution/Timing.h`).

## Correctness check

The benchmark itself only measures time. [scripts/run-correctness.sh](scripts/run-correctness.sh)
checks that GengoDB's answers are actually *right*, by replaying concrete
BSBM query instances against both GengoDB and Fuseki (the reference
implementation) and comparing every answer:

```sh
./scripts/init-db.sh && BACKEND=fuseki ./scripts/init-db.sh   # both DBs for $SCALE
./scripts/run-correctness.sh                                  # or: SCALE=sf5000 ...
CHECK_CORRECTNESS=1 ./scripts/benchmark.sh                    # benchmark, then check
```

It starts whichever server isn't running yet (and stops only those again),
and refuses to reuse a running server that serves a different `$SCALE`.
The GengoDB server is checked exactly as configured in `docker-compose.yml`
(the server flags and image are recorded in `meta.json`), so a change to
the benchmarked setup, e.g. `--enable-cache`, is reflected in the check.

How it works:

1. [scripts/gen-correctness-queries.sh](scripts/gen-correctness-queries.sh)
   runs the BSBM test driver in qualification mode (`-q`) against Fuseki,
   using the `explore` query mix
   ([tools/test-driver/queries/explore/](tools/test-driver/queries/explore/)):
   That yields `CHECK_RUNS` × 25 concrete query instances with BSBM's own 
   parameter distribution, logged to `run.log`. This happens once per
   scale/seed/runs under `results/correctness/reference/`, together with
   a cache of Fuseki's answers; `FORCE=1` regenerates it.
2. [scripts/check-correctness.py](scripts/check-correctness.py) (run
   inside `bsbm-tools`) sends every instance to both endpoints and
   classifies GengoDB's answer. Rows are compared as multisets, or as
   lists under `ORDER BY`. Numeric literals are compared by value, and
   `ORDER BY ... LIMIT` accepts any valid choice among rows tied at the
   cut-off (`match_modulo_ties`). CONSTRUCT/DESCRIBE answers are compared
   as graphs (isomorphism). DESCRIBE output is implementation-defined, so
   queries 9 and 12 are marked informational (`[i]`) and excluded from
   the overall score.

BSBM's own `qualification` tool isn't used for the comparison: it only
compares the columns in `query*valid.txt` and only SELECT queries,
compares the tested run's head with itself (upstream bug in
`Qualification.java`), can't handle ties at a `LIMIT`, and exits on
malformed XML.

Results land in `results/correctness/<run-id>/`:

- `summary.txt`: per-query status counts plus the first failing instances.
- `summary.csv`: the same, one row per query (`correct_pct` =
  `match` + `match_modulo_ties` share).
- `instances.jsonl`: one record per instance with status, row/triple
  counts, query text and a sample of missing/extra rows.
- `meta.json`: endpoints, scale, seed, GengoDB image and server args.

## Configuration

All via environment variables (defaults in `scripts/lib.sh`):

| Variable              | Default   | Meaning                                            |
|-----------------------|-----------|-----------------------------------------------------|
| `BACKEND`              | `gengodb` | Which target to run: `gengodb` or `fuseki`          |
| `SCALE`                | `sf1000`  | Label for this dataset/db (own subdirectory under `data/`) |
| `PRODUCT_COUNT`        | `1000`    | BSBM `-pc`; drives dataset size (~1,000 products ≈ smoke-test scale; standard published BSBM scales are 25,000+) |
| `GENGODB_PORT`         | `8890`    | Host+container port for GengoDB's SPARQL endpoint (`BACKEND=gengodb` only) |
| `GENGODB_SPARQL_PATH`  | `/sparql` | HTTP path GengoDB serves SPARQL on (confirmed correct; `BACKEND=gengodb` only) |
| `FUSEKI_PORT`          | `3030`    | Host+container port for Fuseki (`BACKEND=fuseki` only) |
| `FUSEKI_DATASET`       | `ds`      | Fuseki dataset path segment — endpoint ends up at `/$FUSEKI_DATASET/sparql` (`BACKEND=fuseki` only) |
| `RUNS`                 | `20`      | BSBM `-runs` (measured query-mix repetitions). Upstream BSBM default is 500. |
| `WARMUPS`              | `5`       | BSBM `-w` (warm-up repetitions before measuring). Upstream default is 50. |
| `SEED`                 | `808080`  | BSBM `-seed`, fixed for run-to-run comparability     |
| `CHECK_RUNS`           | `10`      | Query mixes of instances `run-correctness.sh` checks (×26 instances each) |
| `CHECK_TIMEOUT`        | `60`      | Per-query timeout (s) in `run-correctness.sh` |
| `DB_CAPACITY`          | `2000000` | GengoDB `db:capacity` (node/rel/property cap), set before `LOAD` in `init-db.sh`. Default GengoDB cap is 1024, which segfaults on any real BSBM dataset. Unused by Fuseki. |

Example for a larger, closer-to-standard run:

```sh
SCALE=sf25000 PRODUCT_COUNT=25000 RUNS=100 WARMUPS=25 BACKEND=fuseki ./scripts/benchmark.sh
```