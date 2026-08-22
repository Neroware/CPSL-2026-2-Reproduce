module {
  func.func @main() {
    %0 = subop.execution_group (){
      %1 = gsubop.get_external_graph{name = "defaultGraph", id = "gengodb://sparql/settings/defaultGraph#rdf"} : <[graphs_u_1_coffee_vx$0 : !gsubop.node_set<[graphs_u_1_coffee_vx_it$0 : !gsubop.graph_set_iterator<["all"]>]>], [graphs_u_1_coffee_ex$0 : !gsubop.edge_set<[graphs_u_1_coffee_ex_it$0 : !gsubop.graph_set_iterator<["all"]>]>]>
      %2 = gsubop.scan_graph %1 : !gsubop.graph<[graphs_u_1_coffee_vx$0 : !gsubop.node_set<[graphs_u_1_coffee_vx_it$0 : !gsubop.graph_set_iterator<["all"]>]>], [graphs_u_1_coffee_ex$0 : !gsubop.edge_set<[graphs_u_1_coffee_ex_it$0 : !gsubop.graph_set_iterator<["all"]>]>]> @graphs_u_1_u_1::@coffee_vx({type = !gsubop.node_set<[graphs_u_1_coffee_vx_it$0 : !gsubop.graph_set_iterator<["all"]>]>}), @graphs_u_1_u_2::@coffee_ex({type = !gsubop.edge_set<[graphs_u_1_coffee_ex_it$0 : !gsubop.graph_set_iterator<["all"]>]>})
      %3 = subop.nested_map %2 [@graphs_u_1_u_2::@coffee_ex] (%arg0, %arg1) {
        %23 = gsubop.scan_edge_set %arg1 : !gsubop.edge_set<[graphs_u_1_coffee_ex_it$0 : !gsubop.graph_set_iterator<["all"]>]> @edges::@ref({type = !gsubop.edge_ref<[graphs_u_1_coffee_edge$0 : i32], [graphs_u_1_coffee_from$0 : !gsubop.node_ref<[graphs_u_1_coffee_node$0 : i32], [graphs_u_1_coffee_incoming$0 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$0 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$0 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$0 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$0 : !gsubop.property_ref]>], [graphs_u_1_coffee_to$0 : !gsubop.node_ref<[graphs_u_1_coffee_node$1 : i32], [graphs_u_1_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$1 : !gsubop.property_ref]>], [graphs_u_1_coffee_property$2 : !gsubop.property_ref]>})
        tuples.return %23 : !tuples.tuplestream
      }
      %4 = subop.gather %3 @edges::@ref {graphs_u_1_coffee_from$0 => @nodes::@raw({type = !gsubop.node_ref<[graphs_u_1_coffee_node$0 : i32], [graphs_u_1_coffee_incoming$0 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$0 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$0 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$0 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$0 : !gsubop.property_ref]>})}
      %5 = subop.map %4 computes : [@vars::@who({type = !variant.variant})] input : [@nodes::@raw] (%arg0: !gsubop.node_ref<[graphs_u_1_coffee_node$0 : i32], [graphs_u_1_coffee_incoming$0 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$0 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$0 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$0 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$0 : !gsubop.property_ref]>){
        %23 = variant.create_node_ref %arg0 : !gsubop.node_ref<[graphs_u_1_coffee_node$0 : i32], [graphs_u_1_coffee_incoming$0 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$0 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$0 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$0 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$0 : !gsubop.property_ref]>
        tuples.return %23 : !variant.variant
      }
      %6 = gsubop.create_identifier{name = "defaultGraph", id = "http://example.org/eats"} : !gsubop.identifier
      %7 = gsubop.filter_by_identifier %5 @edges::@ref[%6]
      %8 = subop.gather %7 @edges::@ref {graphs_u_1_coffee_to$0 => @nodes_u_1::@raw({type = !gsubop.node_ref<[graphs_u_1_coffee_node$1 : i32], [graphs_u_1_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$1 : !gsubop.property_ref]>})}
      %9 = subop.map %8 computes : [@vars::@what({type = !variant.variant})] input : [@nodes_u_1::@raw] (%arg0: !gsubop.node_ref<[graphs_u_1_coffee_node$1 : i32], [graphs_u_1_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$1 : !gsubop.property_ref]>){
        %23 = variant.create_node_ref %arg0 : !gsubop.node_ref<[graphs_u_1_coffee_node$1 : i32], [graphs_u_1_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_1_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_1_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_1_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_1_coffee_property$1 : !gsubop.property_ref]>
        tuples.return %23 : !variant.variant
      }
      %10 = gsubop.scan_graph %1 : !gsubop.graph<[graphs_u_1_coffee_vx$0 : !gsubop.node_set<[graphs_u_1_coffee_vx_it$0 : !gsubop.graph_set_iterator<["all"]>]>], [graphs_u_1_coffee_ex$0 : !gsubop.edge_set<[graphs_u_1_coffee_ex_it$0 : !gsubop.graph_set_iterator<["all"]>]>]> @graphs_u_2_u_1::@coffee_vx({type = !gsubop.node_set<[graphs_u_1_coffee_vx_it$0 : !gsubop.graph_set_iterator<["all"]>]>}), @graphs_u_2_u_2::@coffee_ex({type = !gsubop.edge_set<[graphs_u_1_coffee_ex_it$0 : !gsubop.graph_set_iterator<["all"]>]>})
      %11 = subop.nested_map %10 [@graphs_u_2_u_1::@coffee_vx] (%arg0, %arg1) {
        %res, %streams = subop.generate[@idents::@lookup({type = !gsubop.identifier})]{
          %26 = gsubop.create_identifier{name = "defaultGraph", id = "http://example.org/coffee"} : !gsubop.identifier
          subop.generate_emit %26 : !gsubop.identifier
          tuples.return
        }
        %23 = subop.map %res computes : [@idents_u_1::@valid({type = i1})] input : [@idents::@lookup] (%arg2: !gsubop.identifier){
          %26 = gsubop.identifier_valid %arg2 : !gsubop.identifier
          tuples.return %26 : i1
        }
        %24 = subop.filter %23 all_true [@idents_u_1::@valid]
        %25 = subop.lookup %24%arg1 [@idents::@lookup] : !gsubop.node_set<[graphs_u_1_coffee_vx_it$0 : !gsubop.graph_set_iterator<["all"]>]> @nodes_u_2::@ref({type = !gsubop.node_ref<[graphs_u_2_coffee_node$0 : i32], [graphs_u_2_coffee_incoming$0 : !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$0 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_2_coffee_outgoing$0 : !gsubop.edge_set<[graphs_u_2_coffee_outgoing_it$0 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_2_coffee_property$0 : !gsubop.property_ref]>})
        tuples.return %25 : !tuples.tuplestream
      }
      %12 = subop.gather %11 @nodes_u_2::@ref {graphs_u_2_coffee_incoming$0 => @edges_u_1::@incoming({type = !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$0 : !gsubop.graph_set_iterator<["incoming"]>]>})}
      %13 = subop.nested_map %12 [@edges_u_1::@incoming] (%arg0, %arg1) {
        %23 = gsubop.scan_edge_set %arg1 : !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$0 : !gsubop.graph_set_iterator<["incoming"]>]> @edges_u_2::@ref({type = !gsubop.edge_ref<[graphs_u_2_coffee_edge$0 : i32], [graphs_u_2_coffee_from$0 : !gsubop.node_ref<[graphs_u_2_coffee_node$1 : i32], [graphs_u_2_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_2_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_2_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_2_coffee_property$1 : !gsubop.property_ref]>], [graphs_u_2_coffee_to$0 : !gsubop.node_ref<[graphs_u_2_coffee_node$2 : i32], [graphs_u_2_coffee_incoming$2 : !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$2 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_2_coffee_outgoing$2 : !gsubop.edge_set<[graphs_u_2_coffee_outgoing_it$2 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_2_coffee_property$2 : !gsubop.property_ref]>], [graphs_u_2_coffee_property$3 : !gsubop.property_ref]>})
        tuples.return %23 : !tuples.tuplestream
      }
      %14 = subop.gather %13 @edges_u_2::@ref {graphs_u_2_coffee_from$0 => @nodes_u_3::@raw({type = !gsubop.node_ref<[graphs_u_2_coffee_node$1 : i32], [graphs_u_2_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_2_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_2_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_2_coffee_property$1 : !gsubop.property_ref]>})}
      %15 = subop.map %14 computes : [@bindings::@s({type = !variant.variant})] input : [@nodes_u_3::@raw] (%arg0: !gsubop.node_ref<[graphs_u_2_coffee_node$1 : i32], [graphs_u_2_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_2_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_2_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_2_coffee_property$1 : !gsubop.property_ref]>){
        %23 = variant.create_node_ref %arg0 : !gsubop.node_ref<[graphs_u_2_coffee_node$1 : i32], [graphs_u_2_coffee_incoming$1 : !gsubop.edge_set<[graphs_u_2_coffee_incoming_it$1 : !gsubop.graph_set_iterator<["incoming"]>]>], [graphs_u_2_coffee_outgoing$1 : !gsubop.edge_set<[graphs_u_2_coffee_outgoing_it$1 : !gsubop.graph_set_iterator<["outgoing"]>]>], [graphs_u_2_coffee_property$1 : !gsubop.property_ref]>
        tuples.return %23 : !variant.variant
      }
      %16 = gsubop.create_identifier{name = "defaultGraph", id = "http://example.org/drinks"} : !gsubop.identifier
      %17 = gsubop.filter_by_identifier %15 @edges_u_2::@ref[%16]
      %18 = subop.create !subop.multimap<[member$0 : !variant.variant], [member$1 : !variant.variant]>
      subop.insert %9%18  : !subop.multimap<[member$0 : !variant.variant], [member$1 : !variant.variant]> {@vars::@what => member$1, @vars::@who => member$0} eq: ([%arg0],[%arg1]) {
        %23 = variant.cmp eq %arg0, %arg1 -> !db.nullable<i1>
        %24 = db.derive_truth %23 : !db.nullable<i1>
        tuples.return %24 : i1
      }
      %19 = subop.lookup %17%18 [@bindings::@s] : !subop.multimap<[member$0 : !variant.variant], [member$1 : !variant.variant]> @lookup::@list({type = !subop.list<!subop.multi_map_entry_ref<<[member$0 : !variant.variant], [member$1 : !variant.variant]>>>})eq: ([%arg0],[%arg1]) {
        %23 = variant.cmp eq %arg0, %arg1 -> !db.nullable<i1>
        %24 = db.derive_truth %23 : !db.nullable<i1>
        tuples.return %24 : i1
      }
      %20 = subop.nested_map %19 [@lookup::@list] (%arg0, %arg1) {
        %23 = subop.scan_list %arg1 : !subop.list<!subop.multi_map_entry_ref<<[member$0 : !variant.variant], [member$1 : !variant.variant]>>> @lookup_u_1::@entryref({type = !subop.multi_map_entry_ref<<[member$0 : !variant.variant], [member$1 : !variant.variant]>>})
        %24 = subop.gather %23 @lookup_u_1::@entryref {member$1 => @vars::@what({type = !variant.variant}), member$0 => @vars::@who({type = !variant.variant})}
        %25 = subop.combine_tuple %24, %arg0
        %26 = subop.map %25 computes : [@map::@pred({type = i1})] input : [@vars::@who,@bindings::@s] (%arg2: !variant.variant,%arg3: !variant.variant){
          %28 = variant.cmp eq %arg2, %arg3 -> !db.nullable<i1>
          %29 = db.derive_truth %28 : !db.nullable<i1>
          tuples.return %29 : i1
        }
        %27 = subop.filter %26 all_true [@map::@pred]
        tuples.return %27 : !tuples.tuplestream
      }
      %21 = subop.create !subop.result_table<[col1$0 : !db.string, col2$0 : !db.string]>
      subop.materialize %20 {@vars::@who => col1$0, @vars::@what => col2$0}, %21 : !subop.result_table<[col1$0 : !db.string, col2$0 : !db.string]>
      %22 = subop.create_from ["who", "what"] %21 : !subop.result_table<[col1$0 : !db.string, col2$0 : !db.string]> -> !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
      subop.execution_group_return %22 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    } -> !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    subop.set_result 0 %0 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string], ["who", "what"]>
    return
  }
}

