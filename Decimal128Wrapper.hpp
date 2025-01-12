//
//  Decimal128Wrapper.hpp
//  DocumentPlus
//
//  Created by Fauzaan on 1/12/25.
//

#ifndef Decimal128Wrapper_hpp
#define Decimal128Wrapper_hpp

#include <stdint.h>
#include <string>

// Forward declaration of BID_UINT128 to avoid Intel library dependency in header
struct BID_UINT128;

class Decimal128Wrapper {
public:
    struct Value {
        uint64_t low64;
        uint64_t high64;
    };
    
    Decimal128Wrapper(Value value);
    ~Decimal128Wrapper();
    
    // Core conversion method
    const char* toString() const;
    
    // Static creation methods
    static Decimal128Wrapper* fromString(const char* str);
    static Decimal128Wrapper* fromInt64(int64_t value);
    
    // Value accessor
    Value getValue() const { return _value; }
    
private:
    Value _value;
    mutable char* _stringBuffer; // Buffer for toString result
    
    std::string _convertToScientificNotation(const std::string& coefficient, int adjustedExponent) const;
    std::string _convertToStandardDecimalNotation(const std::string& coefficient, int exponent) const;
};

#endif /* Decimal128Wrapper_hpp */
