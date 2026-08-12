module {
  func.func @main() {
    %0 = relalg.query (){
      %1 = gpm.named_graph column : @graphs::@defaultGraph({type = !gpm.graph_ref<"defaultGraph", "gengodb://sparql/settings/defaultGraph#rdf">})
      %2 = gpm.basic_graph_pattern %1 (%arg0: !tuples.tuplestream){
        %5 = gpm.triple_pattern %arg0 @graphs::@defaultGraph(?{@vars::@s({type = !gpm.variable_binding})}, ?{@vars::@p({type = !gpm.variable_binding})}, ?{@vars::@o({type = !gpm.variable_binding})})
        tuples.return %5 : !tuples.tuplestream
      }
      %3 = relalg.limit 5 %2
      %4 = relalg.materialize %3 [@vars::@s,@vars::@p,@vars::@o] => ["s", "p", "o"] : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string], ["s", "p", "o"]>
      relalg.query_return %4 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string], ["s", "p", "o"]>
    } -> !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string], ["s", "p", "o"]>
    subop.set_result 0 %0 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string], ["s", "p", "o"]>
    return
  }
}
