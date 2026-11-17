// dattr.hpp: attributes after parsing, for C++ (see dattr.h).
#pragma once

#include "dattr.h"
#include "dparse.hpp"

#include <functional>
#include <new>
#include <optional>
#include <stdexcept>
#include <vector>

namespace dparser {

class AttrTree;

// A node of an attribute tree.
class AttrNode {
public:
    AttrNode(D_AttrTree* t = nullptr, D_AttrNode* n = nullptr) : t_(t), n_(n) {}

    explicit operator bool() const { return n_ != nullptr; }
    bool operator==(const AttrNode& o) const { return n_ == o.n_; }
    bool operator!=(const AttrNode& o) const { return n_ != o.n_; }

    AttrNode parent() const { return AttrNode(t_, d_attr_parent(n_)); }
    int index() const { return d_attr_index(n_); }              // -1 for the root
    size_t num_children() const { return static_cast<size_t>(d_attr_n_children(n_)); }
    AttrNode child(size_t i) const { return AttrNode(t_, d_attr_child(n_, static_cast<int>(i))); }
    ParseNode node() const { return ParseNode(d_attr_parse_node(n_)); }
    int symbol() const { return d_attr_symbol(n_); }
    std::string_view symbol_name() const { return d_attr_symbol_name(t_, n_); }
    int production() const { return d_attr_production(n_); }  // D_RULE_... or -1
    std::string_view text() const { return node().text(); }

    D_AttrNode* c_node() const { return n_; }
    D_AttrTree* c_tree() const { return t_; }

private:
    D_AttrTree* t_;
    D_AttrNode* n_;
};

// An attribute with values of type T.  The equation returns the value, or
// std::nullopt when it has none for this case: a synthesized attribute is
// then undefined, and an inherited one is copied down from an ancestor.
//
//   syn: equation(node, -1)
//   inh: equation(parent, child_index) for a child; equation(root, -1) at the root
template <class T>
class Attr {
public:
    using Equation = std::function<std::optional<T>(AttrNode node, int child_index)>;

    Attr(const char* name, D_AttrKind kind, Equation eq) : eq_(std::move(eq)) {
        static_assert(alignof(T) <= 16, "attribute values are aligned to 16 bytes");
        c_.name = name;
        c_.kind = kind;
        c_.eval = &Attr::eval;
        c_.size = static_cast<int>(sizeof(T));
        c_.free = &Attr::destroy;
        c_.data = this;
    }
    Attr(const Attr&) = delete;
    Attr& operator=(const Attr&) = delete;

    D_Attr* c_attr() { return &c_; }
    const char* name() const { return c_.name; }

    // The value at node, or nullptr if it is undefined or part of a cycle.
    const T* get(AttrNode n) {
        return static_cast<const T*>(d_attr_get(n.c_tree(), n.c_node(), &c_));
    }
    const T* operator()(AttrNode n) { return get(n); }

private:
    static int eval(D_AttrTree* t, D_Attr* a, D_AttrNode* node, int child, void* out) {
        Attr* self = static_cast<Attr*>(a->data);
        std::optional<T> v = self->eq_(AttrNode(t, node), child);
        if (!v) return 0;
        new (out) T(std::move(*v));
        return 1;
    }
    static void destroy(D_Attr*, void* value) { static_cast<T*>(value)->~T(); }

    D_Attr c_;
    Equation eq_;
};

template <class T>
Attr<T> syn(const char* name, typename Attr<T>::Equation eq) {
    return Attr<T>(name, D_ATTR_SYN, std::move(eq));
}

template <class T>
Attr<T> inh(const char* name, typename Attr<T>::Equation eq) {
    return Attr<T>(name, D_ATTR_INH, std::move(eq));
}

// An attribute tree over a saved parse tree.  The attributes and the parse
// tree must outlive it.
class AttrTree {
public:
    template <class... A>
    AttrTree(Parser& parser, const ParseTree& tree, A&... attrs) {
        std::vector<D_Attr*> v = {attrs.c_attr()...};
        t_ = d_attr_tree(parser.c_parser(), tree.c_root(), v.data(), static_cast<int>(v.size()), this);
        if (!t_) throw std::runtime_error("AttrTree needs a saved parse tree");
    }
    ~AttrTree() { d_attr_tree_free(t_); }
    AttrTree(const AttrTree&) = delete;
    AttrTree& operator=(const AttrTree&) = delete;

    AttrNode root() const { return AttrNode(t_, d_attr_root(t_)); }
    int cycles() const { return d_attr_cycles(t_); }
    void set_cycle_fn(D_AttrCycleFn fn) { d_attr_set_cycle_fn(t_, fn); }
    D_AttrTree* c_tree() const { return t_; }

private:
    D_AttrTree* t_;
};

}  // namespace dparser
