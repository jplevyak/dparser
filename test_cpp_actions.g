{
#include "dparse.hpp"
#include <iostream>
}

S: A B {
  std::cout << "Parsed S: [" << $c0.text() << "] and [" << $c1.text() << "]" << std::endl;
};

A: 'a';
B: 'b';
