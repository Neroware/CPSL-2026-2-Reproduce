#include <iostream>
#include <cstdint>
#include <cassert>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <chrono>

struct MemoryHelper {
   static uint8_t* resize(uint8_t* old, size_t oldNumBytes, size_t newNumBytes) {
      uint8_t* newBytes = (uint8_t*) malloc(newNumBytes);
      memcpy(newBytes, old, oldNumBytes);
      free(old);
      return newBytes;
   }
   static void fill(uint8_t* ptr, uint8_t val, size_t size) {
      memset(ptr, val, size);
   }
   static void zero(uint8_t* ptr, size_t size) { fill(ptr, 0, size); }
};

template <class T>
struct LegacyFixedSizedBuffer {
   LegacyFixedSizedBuffer(size_t size) : ptr((T*) malloc(size * sizeof(T))) {
      MemoryHelper::zero((uint8_t*) ptr, size * sizeof(T));
   }
   T* ptr;
   void setNewSize(size_t newSize) {
      free(ptr);
      ptr = (T*) malloc(newSize * sizeof(T));
      MemoryHelper::zero((uint8_t*) ptr, newSize * sizeof(T));
   }
   T& at(size_t i) {
      return ptr[i];
   }
   T* getPtr(size_t i) {
      return &ptr[i];
   }
   ~LegacyFixedSizedBuffer() {
      free(ptr);
   }
};

using node_id_t = int32_t;
using rel_id_t  = int32_t;
using rel_type_t  = int32_t;
static constexpr int32_t GRAPH_NONE = -1;

// Generic doubly-linked adjacency-list graph data structure with fixed size entries.
template <typename NodePayload, typename RelPayload>
class Graph {
public:
    struct NodeEntry {
        node_id_t   firstRelId;
        bool        inUse;
        uint8_t     labels[5] = {0};
        uint8_t     extra = 0;
        NodePayload payload;
    };
    struct RelEntry {
        node_id_t  firstNodeId;
        node_id_t  secondNodeId;
        rel_type_t typeId;
        rel_id_t   firstPrevRelId;
        rel_id_t   firstNextRelId;
        rel_id_t   secondPrevRelId;
        rel_id_t   secondNextRelId;
        bool       inUse;
        uint8_t    firstInChainMarker = 0;
        RelPayload payload;
    };
    Graph(int32_t nodeCapacity, int32_t relCapacity)
      : nodes_(nodeCapacity), rels_(relCapacity),
        nodeMark_(0), relMark_(0),
        nodeCap_(nodeCapacity), relCap_(relCapacity) {}
    Graph(node_id_t nodeHighWater, LegacyFixedSizedBuffer<NodeEntry>&& nodes,
        rel_id_t relHighWater, LegacyFixedSizedBuffer<RelEntry>&& rels)
            : nodes_(std::move(nodes)), rels_(std::move(rels)),
            nodeMark_(nodeHighWater), relMark_(relHighWater),
            nodeCap_(nodeHighWater), relCap_(relHighWater) {}
   ~Graph() = default;
    NodeEntry& node(node_id_t id) const {
        assert(id >= 0 && id < nodeMark_);
        return nodes_.ptr[id];
    }
    RelEntry& rel(rel_id_t id) const {
        assert(id >= 0 && id < relMark_);
        return rels_.ptr[id];
    }
    uint8_t* nodeStorePtr() const { return reinterpret_cast<uint8_t*>(nodes_.ptr); }
    uint8_t* relStorePtr() const { return reinterpret_cast<uint8_t*>(rels_.ptr); }
    int32_t nodeHighWater() const { return nodeMark_; }
    int32_t relHighWater() const { return relMark_; }
    size_t freeNodes() const { return freeNodes_.size(); }
    size_t freeRels() const { return freeRels_.size(); }
    node_id_t addNode(NodePayload initPayload) {
        node_id_t id = allocNode();
        NodeEntry& n = nodes_.ptr[id];
        n.inUse = true;
        n.firstRelId = GRAPH_NONE;
        n.payload = initPayload;
        return id;
    }
    rel_id_t addRelationship(node_id_t from, node_id_t to, uint32_t typeId, RelPayload initPayload) {
        rel_id_t id = allocRel();
        RelEntry& r = rels_.ptr[id];
        r.inUse = true;
        r.firstNodeId = from;
        r.secondNodeId = to;
        r.typeId = typeId;
        r.firstPrevRelId = GRAPH_NONE;
        r.firstNextRelId = GRAPH_NONE;
        r.secondPrevRelId = GRAPH_NONE;
        r.secondNextRelId = GRAPH_NONE;
        r.payload = initPayload;
        linkRelToNode(id, from, /*nodeIsFirst=*/true);
        if (from != to)
            linkRelToNode(id, to, /*nodeIsFirst=*/false);
        return id;
   }
    void removeRelationship(rel_id_t id) {
        RelEntry& r = rels_.ptr[id];
        assert(r.inUse);
        unlinkRelFromNode(id, r.firstNodeId);
        if (r.firstNodeId != r.secondNodeId)
            unlinkRelFromNode(id, r.secondNodeId);
        r.inUse = false;
        freeRels_.push_back(id);
    }
    // Removes all relationships incident to the node, then frees the node.
    // Does NOT clean up relationship/node payloads.
    void removeNode(node_id_t id) {
        NodeEntry& n = nodes_.ptr[id];
        assert(n.inUse);
        rel_id_t cur = n.firstRelId;
        while (cur != GRAPH_NONE) {
            RelEntry& r = rels_.ptr[cur];
            rel_id_t next = (r.firstNodeId == id) ? r.firstNextRelId : r.secondNextRelId;
            removeRelationship(cur);
            cur = next;
        }
        n.inUse = false;
        n.firstRelId = GRAPH_NONE;
        freeNodes_.push_back(id);
    }
    void clear() {
        nodeMark_ = relMark_ = 0;
        freeNodes_.clear();
        freeRels_.clear();
    }
    NodeEntry& newNode() {
        assert(nodeMark_ < nodeCap_ && "node capacity exceeded");
        return nodes_.ptr[nodeMark_++];
    }
    RelEntry& newRel() {
        assert(relMark_ < relCap_ && "rel capacity exceeded");
        return rels_.ptr[relMark_++];
    }

private:
    node_id_t allocNode() {
        if (!freeNodes_.empty()) {
            auto id = freeNodes_.back();
            freeNodes_.pop_back();
            return id;
        }
        assert(nodeMark_ < nodeCap_ && "node capacity exceeded");
        return nodeMark_++;
    }
    rel_id_t allocRel() {
        if (!freeRels_.empty()) {
            auto id = freeRels_.back();
            freeRels_.pop_back();
            return id;
        }
        assert(relMark_ < relCap_ && "rel capacity exceeded");
        return relMark_++;
    }
    void linkRelToNode(rel_id_t relId, node_id_t nodeId, bool nodeIsFirst) {
        NodeEntry& n = nodes_.ptr[nodeId];
        RelEntry& r = rels_.ptr[relId];
        rel_id_t oldHead = n.firstRelId;
        if (nodeIsFirst) {
            r.firstNextRelId = oldHead;
            r.firstPrevRelId = GRAPH_NONE;
        } 
        else {
            r.secondNextRelId = oldHead;
            r.secondPrevRelId = GRAPH_NONE;
        }
        if (oldHead != GRAPH_NONE) {
            RelEntry& head = rels_.ptr[oldHead];
            if (head.firstNodeId == nodeId)
                head.firstPrevRelId = relId;
            else
                head.secondPrevRelId = relId;
        }
        
        n.firstRelId = relId;
   }
   void unlinkRelFromNode(rel_id_t relId, node_id_t nodeId) {
        RelEntry& r = rels_.ptr[relId];
        NodeEntry& n = nodes_.ptr[nodeId];
        bool isFirst = (r.firstNodeId == nodeId);
        rel_id_t prevId = isFirst ? r.firstPrevRelId : r.secondPrevRelId;
        rel_id_t nextId = isFirst ? r.firstNextRelId : r.secondNextRelId;
        if (prevId != GRAPH_NONE) {
            RelEntry& prev = rels_.ptr[prevId];
            if (prev.firstNodeId == nodeId) { 
                prev.firstNextRelId  = nextId;
            }
            else {
                prev.secondNextRelId = nextId;
            }
        } 
        else {
            n.firstRelId = nextId;
        }
        if (nextId != GRAPH_NONE) {
            RelEntry& next = rels_.ptr[nextId];
            if (next.firstNodeId == nodeId) {
                next.firstPrevRelId = prevId;
            }
            else {
                next.secondPrevRelId = prevId;
            }
        }
   }

private:
   LegacyFixedSizedBuffer<NodeEntry> nodes_;
   LegacyFixedSizedBuffer<RelEntry> rels_;
   int32_t nodeMark_, relMark_;
   int32_t nodeCap_,  relCap_;
   std::vector<node_id_t> freeNodes_;
   std::vector<rel_id_t> freeRels_;
}; // Graph

struct node_property_t {
    double rank;
    double nextRank;
    int l;
};
struct rel_property_t {
    // intentionally empty...
};

Graph<node_property_t, rel_property_t>* createGraph() {
    auto g = new Graph<node_property_t, rel_property_t>(8, 64);
    for (int i = 0; i < 5; i++) {
        g->addNode(node_property_t{0.0, 0.0, 0});
    }
    auto property = rel_property_t{};
    g->addRelationship(0, 1, 0, property);
    g->addRelationship(0, 3, 0, property);
    g->addRelationship(1, 2, 0, property);
    g->addRelationship(2, 4, 0, property);
    g->addRelationship(3, 4, 0, property);
    g->addRelationship(4, 1, 0, property);
    return g;
}

void pagerank(Graph<node_property_t, rel_property_t>* graph, int repeats, double damping) {
    int nNodes = graph->nodeHighWater();
    for (int n = 0; n < nNodes; n++) {
        auto& node = graph->node(n);
        node.payload.rank = 1.0 / nNodes;
        auto nextRel = node.firstRelId;
        int degree = 0;
        while (nextRel >= 0) {
            auto& rel = graph->rel(nextRel);
            if (rel.inUse && rel.firstNodeId == n)
                degree++;
            nextRel = n == rel.firstNodeId ? rel.firstNextRelId : rel.secondNextRelId;
        }
        node.payload.l = degree;
    }

    for (int iter = 0; iter < repeats; iter++) {
        for(int n = 0; n < nNodes; n++) {
            graph->node(n).payload.nextRank = 0.15 / nNodes;
        }
        for (int n = 0; n < nNodes; n++) {
            auto& node = graph->node(n);
            auto nextRel = node.firstRelId;
            while (nextRel >= 0) {
                auto& rel = graph->rel(nextRel);
                if (rel.inUse && rel.firstNodeId == n) {
                    auto& toNode = graph->node(rel.secondNodeId);
                    toNode.payload.nextRank += damping * (node.payload.rank / node.payload.l);
                }
                nextRel = n == rel.firstNodeId ? rel.firstNextRelId : rel.secondNextRelId;
            }
        }
        for (int n = 0; n < nNodes; n++) {
            auto& node = graph->node(n);
            node.payload.rank = node.payload.nextRank;
        }
    }

}

int main() {
    std::cout << "Running PageRank..." << std::endl;
    auto g = createGraph();

    auto start = std::chrono::high_resolution_clock::now();
    pagerank(g, 1000, 0.85);
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "pagerank.cpp" << "\t" << duration.count() << " microseconds" << std::endl;
    for (int n = 0; n < g->nodeHighWater(); n++) {
        std::cout << "n = " << n
            << ", rank = " << g->node(n).payload.rank
            << ", l = " << g->node(n).payload.l
            << std::endl;
    }

    delete g;
    return 0;
}