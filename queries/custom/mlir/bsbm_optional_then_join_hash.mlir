// BSBM performance snippet: binding compatible inner join on a variable coming from an OPTIONAL, forced to the hash join.
// Mirrors test/gengodb/gpm/snippets/optional/optional_then_join_hash.mlir on the BSBM sample data (resources/ttl/bsbm).
// Sizes: 2000 offers (1284/673/43 by producer), 100 bsbm:producer triples (59/34/7 products per producer) -> 98939 result rows.
// PREFIX bsbm: <http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/vocabulary/>
// SELECT ?offer ?product ?producer ?other WHERE {
//   ?offer bsbm:product ?product . OPTIONAL { ?product bsbm:producer ?producer . } ?other bsbm:producer ?producer .
// }
module {
  func.func @main() {
    %0 = relalg.query (){
      %1 = gpm.relalg.named_graph column : @graphs_u_1::@ref({type = !gpm.graph_ref<"defaultGraph", "gengodb://sparql/settings/defaultGraph#rdf">})
      %2 = gpm.relalg.triple_pattern %1 @graphs_u_1::@ref(?{@vars::@offer({type = !variant.variant})}, id{"http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/vocabulary/product"}, ?{@vars::@product({type = !variant.variant})})
      %3 = gpm.relalg.named_graph column : @graphs_u_2::@ref({type = !gpm.graph_ref<"defaultGraph", "gengodb://sparql/settings/defaultGraph#rdf">})
      %4 = gpm.relalg.triple_pattern %3 @graphs_u_2::@ref(?{@bindings::@s({type = !variant.variant})}, id{"http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/vocabulary/producer"}, ?{@vars::@producer({type = !variant.variant})})
      %5 = relalg.outerjoin %2, %4 (%arg0: !tuples.tuple){
        %10 = tuples.getcol %arg0 @vars::@product : !variant.variant
        %11 = tuples.getcol %arg0 @bindings::@s : !variant.variant
        %12 = gpm.bindings_compatible %10 : !variant.variant, %11 : !variant.variant
        tuples.return %12 : i1
      }  mapping: {@outerjoin::@producer({type = !db.nullable<!variant.variant>})=[@vars::@producer]} attributes {bindingCompatible = [1 : i8], leftHash = [#tuples.columnref<@vars::@product>], nullsEqual = [0 : i8], rightHash = [#tuples.columnref<@bindings::@s>]}
      %6 = gpm.relalg.named_graph column : @graphs_u_3::@ref({type = !gpm.graph_ref<"defaultGraph", "gengodb://sparql/settings/defaultGraph#rdf">})
      %7 = gpm.relalg.triple_pattern %6 @graphs_u_3::@ref(?{@vars::@other({type = !variant.variant})}, id{"http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/vocabulary/producer"}, ?{@bindings_u_1::@o({type = !variant.variant})})
      %8 = relalg.join %5, %7 (%arg0: !tuples.tuple){
        %10 = tuples.getcol %arg0 @outerjoin::@producer : !db.nullable<!variant.variant>
        %11 = tuples.getcol %arg0 @bindings_u_1::@o : !variant.variant
        %12 = gpm.bindings_compatible %10 : !db.nullable<!variant.variant>, %11 : !variant.variant
        tuples.return %12 : i1
      } attributes {impl = "hash", useHashJoin, bindingCompatible = [1 : i8], gpm.merge = [#tuples.columndef<@merge::@producer,!db.nullable<!variant.variant>,[#tuples.columnref<@outerjoin::@producer>, #tuples.columnref<@bindings_u_1::@o>]>], leftHash = [#tuples.columnref<@outerjoin::@producer>], nullsEqual = [0 : i8], rightHash = [#tuples.columnref<@bindings_u_1::@o>]}
      %9 = relalg.materialize %8 [@vars::@offer,@vars::@product,@merge::@producer,@vars::@other] => ["offer", "product", "producer", "other"] : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string, col4$0 : !db.string], ["offer", "product", "producer", "other"]>
      relalg.query_return %9 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string, col4$0 : !db.string], ["offer", "product", "producer", "other"]>
    } -> !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string, col4$0 : !db.string], ["offer", "product", "producer", "other"]>
    subop.set_result 0 %0 : !subop.local_table<[col1$0 : !db.string, col2$0 : !db.string, col3$0 : !db.string, col4$0 : !db.string], ["offer", "product", "producer", "other"]>
    return
  }
}
