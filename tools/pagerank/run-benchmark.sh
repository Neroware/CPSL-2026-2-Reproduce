#!/usr/bin/bash

rm -f *.log

readonly GRAPH_DIR="../.."
readonly RUN_MLIR="../../../../build/run-mlir"

# Generate PageRank runtimes 
#for i in $(seq 1 $1); do 
#    $RUN_MLIR $GRAPH_DIR/snippets/pagerank.mlir | grep pagerank.mlir >> pagerank_graph.log
#    $RUN_MLIR ../../../lit/SubOp/pagerank.mlir | grep pagerank.mlir >> pagerank_classic.log
#done

# Compile and run the C++ implementation
g++ -o ./cpp/pagerank ./cpp/pagerank.cpp
for i in $(seq 1 $1); do 
    ./cpp/pagerank | grep pagerank.cpp >> pagerank_cpp.log
done