module {
  func.func @main() {
    %0 = relalg.query (){
      %1 = gpm.named_graph column : @graphs_u_1::@ref({type = !gpm.graph_ref<"defaultGraph", "gengodb://sparql/settings/defaultGraph#rdf">})
      %2 = gpm.triple_pattern %1 @graphs_u_1::@ref(?{@vars::@who({type = !gpm.variable_binding})}, id{"http://example.org/eats"}, ?{@vars::@what({type = !gpm.variable_binding})})
      %3 = gpm.named_graph column : @graphs_u_2::@ref({type = !gpm.graph_ref<"defaultGraph", "gengodb://sparql/settings/defaultGraph#rdf">})
      %4 = gpm.triple_pattern %3 @graphs_u_2::@ref(?{@vars::@who}, id{"http://example.org/drinks"}, id{"http://example.org/coffee"}) {bindings = {s = #tuples.columndef<@bindings::@s,!gpm.variable_binding,[#tuples.columnref<@vars::@who>]>}}
      %5 = relalg.join %2, %4 (%arg0: !tuples.tuple){
        %7 = tuples.getcol %arg0 @vars::@who : !gpm.variable_binding
        %8 = tuples.getcol %arg0 @bindings::@s : !gpm.variable_binding
        %9 = gpm.identifiers_equal %7 : !gpm.variable_binding, %8 : !gpm.variable_binding
        tuples.return %9 : i1
      } attributes {impl = "hash", leftHash = [#tuples.columnref<@vars::@who>], nullMatchesAll = [1 : i8], nullsEqual = [0 : i8], rightHash = [#tuples.columnref<@bindings::@s>], useHashJoin}
      %6 = relalg.materialize %5 [@vars::@who,@vars::@what] => ["who", "what"] : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
      relalg.query_return %6 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    } -> !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    subop.set_result 0 %0 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    return
  }
}

