module {
  func.func @main() {
    %0 = subop.execution_group (){
      %1 = gsubop.get_external_graph{name = "defaultGraph", id = "gengodb://sparql/settings/defaultGraph#rdf"} : <[vx0 : !gsubop.node_set<[vx0_it : !gsubop.graph_set_iterator<["all"]>]>], [ex0 : !gsubop.edge_set<[ex0_it : !gsubop.graph_set_iterator<["all"]>]>]>
      %2 = gsubop.scan_graph %1 : !gsubop.graph<[vx0 : !gsubop.node_set<[vx0_it : !gsubop.graph_set_iterator<["all"]>]>], [ex0 : !gsubop.edge_set<[ex0_it : !gsubop.graph_set_iterator<["all"]>]>]> @graph::@vx({type = !gsubop.node_set<[vx0_it : !gsubop.graph_set_iterator<["all"]>]>}), @graph::@ex({type = !gsubop.edge_set<[ex0_it : !gsubop.graph_set_iterator<["all"]>]>})

      %3 = subop.nested_map %2 [@graph::@vx] (%arg0, %arg1) {
        %res, %streams = subop.generate[@idents::@lookup({type = !gsubop.identifier})]{
          %a = gsubop.create_identifier{name = "defaultGraph", id = "http://example.org/coffee"} : !gsubop.identifier
          subop.generate_emit %a : !gsubop.identifier
          tuples.return
        }
        %b = subop.map %res computes : [@idents::@valid({type = i1})] input : [@idents::@lookup] (%arg2: !gsubop.identifier){
          %c = gsubop.identifier_valid %arg2 : !gsubop.identifier
          tuples.return %c : i1
        }
        %d = subop.filter %b all_true [@idents::@valid]
        %e = subop.lookup %d %arg1 [@idents::@lookup] : !gsubop.node_set<[vx0_it : !gsubop.graph_set_iterator<["all"]>]> @coffee::@ref({type = !gsubop.node_ref<[coffee_id : i32], [coffee_incoming : !gsubop.edge_set<[coffee_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [coffee_outgoing : !gsubop.edge_set<[coffee_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [coffee_property : !gsubop.property_ref]>})
        tuples.return %e : !tuples.tuplestream
      }

      %4 = subop.gather %3 @coffee::@ref {coffee_incoming => @coffee::@incoming({type = !gsubop.edge_set<[coffee_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>})}
      %5 = subop.nested_map %4 [@coffee::@incoming] (%arg0, %arg1) {
        %f = gsubop.scan_edge_set %arg1 : !gsubop.edge_set<[coffee_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]> @drinks::@ref({type = !gsubop.edge_ref<[drinks_id : i32], [drinks_from : !gsubop.node_ref<[who_id : i32], [who_incoming : !gsubop.edge_set<[who_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [who_outgoing : !gsubop.edge_set<[who_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [who_property : !gsubop.property_ref]>], [drinks_to : !gsubop.node_ref<[coffee_id : i32], [coffee_incoming : !gsubop.edge_set<[coffee_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [coffee_outgoing : !gsubop.edge_set<[coffee_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [coffee_property : !gsubop.property_ref]>], [drinks_property : !gsubop.property_ref]>})
        tuples.return %f : !tuples.tuplestream
      }
      %6 = gsubop.create_identifier{name = "defaultGraph", id = "http://example.org/drinks"} : !gsubop.identifier
      %7 = gsubop.filter_by_identifier %5 @drinks::@ref[%6]
      %8 = subop.gather %7 @drinks::@ref {drinks_from => @who::@ref({type = !gsubop.node_ref<[who_id : i32], [who_incoming : !gsubop.edge_set<[who_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [who_outgoing : !gsubop.edge_set<[who_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [who_property : !gsubop.property_ref]>})}
      %9 = subop.map %8 computes : [@vars::@who({type = !variant.variant})] input : [@who::@ref] (%arg0: !gsubop.node_ref<[who_id : i32], [who_incoming : !gsubop.edge_set<[who_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [who_outgoing : !gsubop.edge_set<[who_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [who_property : !gsubop.property_ref]>){
        %g = variant.create_node_ref %arg0 : !gsubop.node_ref<[who_id : i32], [who_incoming : !gsubop.edge_set<[who_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [who_outgoing : !gsubop.edge_set<[who_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [who_property : !gsubop.property_ref]>
        tuples.return %g : !variant.variant
      }

      %10 = subop.gather %9 @who::@ref {who_outgoing => @who::@outgoing({type = !gsubop.edge_set<[who_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>})}
      %11 = subop.nested_map %10 [@who::@outgoing] (%arg0, %arg1) {
        %h = gsubop.scan_edge_set %arg1 : !gsubop.edge_set<[who_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]> @eats::@ref({type = !gsubop.edge_ref<[eats_id : i32], [eats_from : !gsubop.node_ref<[who_id : i32], [who_incoming : !gsubop.edge_set<[who_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [who_outgoing : !gsubop.edge_set<[who_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [who_property : !gsubop.property_ref]>], [eats_to : !gsubop.node_ref<[what_id : i32], [what_incoming : !gsubop.edge_set<[what_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [what_outgoing : !gsubop.edge_set<[what_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [what_property : !gsubop.property_ref]>], [eats_property : !gsubop.property_ref]>})
        tuples.return %h : !tuples.tuplestream
      }
      %12 = gsubop.create_identifier{name = "defaultGraph", id = "http://example.org/eats"} : !gsubop.identifier
      %13 = gsubop.filter_by_identifier %11 @eats::@ref[%12]
      %14 = subop.gather %13 @eats::@ref {eats_to => @what::@ref({type = !gsubop.node_ref<[what_id : i32], [what_incoming : !gsubop.edge_set<[what_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [what_outgoing : !gsubop.edge_set<[what_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [what_property : !gsubop.property_ref]>})}
      %15 = subop.map %14 computes : [@vars::@what({type = !variant.variant})] input : [@what::@ref] (%arg0: !gsubop.node_ref<[what_id : i32], [what_incoming : !gsubop.edge_set<[what_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [what_outgoing : !gsubop.edge_set<[what_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [what_property : !gsubop.property_ref]>){
        %i = variant.create_node_ref %arg0 : !gsubop.node_ref<[what_id : i32], [what_incoming : !gsubop.edge_set<[what_incoming_it : !gsubop.graph_set_iterator<["incoming"]>]>], [what_outgoing : !gsubop.edge_set<[what_outgoing_it : !gsubop.graph_set_iterator<["outgoing"]>]>], [what_property : !gsubop.property_ref]>
        tuples.return %i : !variant.variant
      }

      %16 = subop.create !subop.result_table<[col1$0 : !db.string, col2$0 : !db.string]>
      subop.materialize %15 {@vars::@who => col1$0, @vars::@what => col2$0}, %16 : !subop.result_table<[col1$0 : !db.string, col2$0 : !db.string]>
      %17 = subop.create_from ["who", "what"] %16 : !subop.result_table<[col1$0 : !db.string, col2$0 : !db.string]> -> !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
      subop.execution_group_return %17 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    } -> !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    subop.set_result 0 %0 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    return
  }
}
