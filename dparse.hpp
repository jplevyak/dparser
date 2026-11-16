// dparse.hpp
#pragma once

#include "dparse.h"

#include <string_view>
#include <iterator>
#include <memory>
#include <stdexcept>
#include <cstdint>
#include <optional>
#include <string>

namespace dparser {

class ParseNode {
public:
    // Iterator class for range-based for loops over children
    class ChildIterator {
    public:
        using iterator_category = std::forward_iterator_tag;
        using value_type        = ParseNode;
        using difference_type   = std::ptrdiff_t;
        using pointer           = ParseNode*;
        using reference         = ParseNode;

        ChildIterator(D_ParseNode* parent = nullptr, int index = 0)
            : parent_(parent), index_(index) {}

        reference operator*() const;
        // pointer operator->() const is omitted because it returns a proxy object, not a reference
        
        ChildIterator& operator++() { index_++; return *this; }
        ChildIterator operator++(int) { ChildIterator tmp = *this; ++(*this); return tmp; }
        friend bool operator==(const ChildIterator& a, const ChildIterator& b) {
            return a.parent_ == b.parent_ && a.index_ == b.index_;
        }
        friend bool operator!=(const ChildIterator& a, const ChildIterator& b) {
            return !(a == b);
        }

    private:
        D_ParseNode* parent_;
        int index_;
    };

    class ChildRange {
    public:
        ChildRange(D_ParseNode* parent) : parent_(parent) {}
        ChildIterator begin() const { return ChildIterator(parent_, 0); }
        ChildIterator end() const { return ChildIterator(parent_, parent_ ? d_get_number_of_children(parent_) : 0); }
    private:
        D_ParseNode* parent_;
    };

    explicit ParseNode(D_ParseNode* node = nullptr) : node_(node) {}

    bool is_valid() const { return node_ != nullptr; }
    explicit operator bool() const { return is_valid(); }

    D_ParseNode* c_node() const { return node_; }

    int symbol() const { return node_ ? node_->symbol : 0; }
    
    std::string_view text() const {
        if (!node_ || !node_->start_loc.s || !node_->end) return {};
        // Use std::max to avoid undefined behavior if end pointer is somehow before start
        size_t len = node_->end > node_->start_loc.s ? static_cast<size_t>(node_->end - node_->start_loc.s) : 0;
        return std::string_view(node_->start_loc.s, len);
    }

    std::string_view text_skip() const {
        if (!node_ || !node_->start_loc.s || !node_->end_skip) return {};
        size_t len = node_->end_skip > node_->start_loc.s ? static_cast<size_t>(node_->end_skip - node_->start_loc.s) : 0;
        return std::string_view(node_->start_loc.s, len);
    }

    template<typename T>
    T* user_data() const {
        if (!node_) return nullptr;
        return reinterpret_cast<T*>(&node_->user);
    }

    size_t num_children() const {
        return node_ ? static_cast<size_t>(d_get_number_of_children(node_)) : 0;
    }

    ParseNode child(size_t index) const {
        return ParseNode(d_get_child(node_, static_cast<int>(index)));
    }

    ChildRange children() const {
        return ChildRange(node_);
    }

    std::optional<ParseNode> find_in_tree(int symbol) const {
        if (!node_) return std::nullopt;
        D_ParseNode* found = d_find_in_tree(node_, symbol);
        if (found) return ParseNode(found);
        return std::nullopt;
    }

private:
    D_ParseNode* node_;
};

inline ParseNode ParseNode::ChildIterator::operator*() const {
    return ParseNode(d_get_child(parent_, index_));
}

// Owns the result of a parse.  It must not outlive the Parser that made it.
class ParseTree {
public:
    ParseTree() : parser_(nullptr), root_(nullptr) {}
    ParseTree(D_Parser* parser, D_ParseNode* root) : parser_(parser), root_(root) {}

    ~ParseTree() { release(); }

    ParseTree(const ParseTree&) = delete;
    ParseTree& operator=(const ParseTree&) = delete;

    ParseTree(ParseTree&& other) noexcept : parser_(other.parser_), root_(other.root_) {
        other.parser_ = nullptr;
        other.root_ = nullptr;
    }

    ParseTree& operator=(ParseTree&& other) noexcept {
        if (this != &other) {
            release();
            parser_ = other.parser_;
            root_ = other.root_;
            other.parser_ = nullptr;
            other.root_ = nullptr;
        }
        return *this;
    }

    // True if the parse succeeded (check Parser::syntax_errors() too).
    bool is_valid() const { return root_ != nullptr; }
    explicit operator bool() const { return is_valid(); }

    // True if a tree was kept: the parse succeeded and save_parse_tree was on.
    bool has_tree() const { return root_ != nullptr && root_ != NO_DPN; }

    // The root node, or an invalid node if no tree was kept.
    ParseNode root() const { return ParseNode(has_tree() ? root_ : nullptr); }
    D_ParseNode* c_root() const { return has_tree() ? root_ : nullptr; }

private:
    void release() {
        // free_D_ParseNode frees the whole tree and accepts the NO_DPN placeholder.
        if (root_ && parser_) free_D_ParseNode(parser_, root_);
        root_ = nullptr;
    }

    D_Parser* parser_;
    D_ParseNode* root_;
};

class Parser {
public:
    Parser(struct D_ParserTables* tables, int sizeof_ParseNode_User = 0) {
        parser_ = new_D_Parser(tables, sizeof_ParseNode_User);
        if (!parser_) {
            throw std::runtime_error("Failed to initialize D_Parser");
        }
        // ParseTree exists to hold a tree, so keep it by default.
        parser_->save_parse_tree = 1;
    }

    ~Parser() {
        if (parser_) {
            free_D_Parser(parser_);
        }
    }

    Parser(const Parser&) = delete;
    Parser& operator=(const Parser&) = delete;

    Parser(Parser&& other) noexcept : parser_(other.parser_) {
        other.parser_ = nullptr;
    }

    Parser& operator=(Parser&& other) noexcept {
        if (this != &other) {
            if (parser_) free_D_Parser(parser_);
            parser_ = other.parser_;
            other.parser_ = nullptr;
        }
        return *this;
    }

    D_Parser* c_parser() const { return parser_; }

    void set_save_parse_tree(bool save) {
        if (parser_) parser_->save_parse_tree = save;
    }

    void set_loc(const char* pathname, int line = 1, int col = 0) {
        if (parser_) {
            parser_->loc.pathname = const_cast<char*>(pathname);
            parser_->loc.line = line;
            parser_->loc.col = col;
        }
    }

    void set_syntax_error_fn(D_SyntaxErrorFn fn) {
        if (parser_) parser_->syntax_error_fn = fn;
    }

    void set_ambiguity_fn(D_AmbiguityFn fn) {
        if (parser_) parser_->ambiguity_fn = fn;
    }

    int syntax_errors() const {
        return parser_ ? parser_->syntax_errors : 0;
    }

    ParseTree parse(const char* buf, int buf_len) {
        if (!parser_) return ParseTree();
        // dparse expects a mutable char pointer due to legacy C signatures, 
        // but scan logic acts efficiently as read-only.
        D_ParseNode* root = dparse(parser_, const_cast<char*>(buf), buf_len);
        return ParseTree(parser_, root);
    }

    ParseTree parse(std::string_view buf) {
        return parse(buf.data(), static_cast<int>(buf.length()));
    }

    ParseTree parse(const std::string& buf) {
        return parse(buf.data(), static_cast<int>(buf.length()));
    }

private:
    D_Parser* parser_;
};

} // namespace dparser
