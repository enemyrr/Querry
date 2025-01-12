//
//  Decimal128Wrapper.cpp
//  DocumentPlus
//
//  Created by Fauzaan on 1/12/25.
//

#include "Decimal128Wrapper.hpp"
#include <bid_conf.h>
#include <bid_functions.h>
#include <cstring>

Decimal128Wrapper::Decimal128Wrapper(Value value) : _value(value), _stringBuffer(nullptr) {}

Decimal128Wrapper::~Decimal128Wrapper() {
    if (_stringBuffer) {
        delete[] _stringBuffer;
    }
}

// Convert the internal decimal128 value to a string representation
const char* Decimal128Wrapper::toString() const {
    // Clean up previous buffer if it exists
    if (_stringBuffer) {
        delete[] _stringBuffer;
        _stringBuffer = nullptr;
    }
    
    BID_UINT128 dec128;
    dec128.w[0] = _value.low64;
    dec128.w[1] = _value.high64;
    
    // Check for special values (NaN, Infinity)
    if (bid128_isNaN(dec128)) {
        _stringBuffer = new char[4];
        strcpy(_stringBuffer, "NaN");
        return _stringBuffer;
    }
    
    if (bid128_isInf(dec128)) {
        if (bid128_isSigned(dec128)) {
            _stringBuffer = new char[10];
            strcpy(_stringBuffer, "-Infinity");
        } else {
            _stringBuffer = new char[9];
            strcpy(_stringBuffer, "Infinity");
        }
        return _stringBuffer;
    }
    
    // For regular numbers, use bid128_to_string
    char tempBuffer[1 + 34 + 1 + 1 + 4 + 1]; // sign + mantissa + E + exp_sign + exp + null
    uint32_t flags = 0;
    bid128_to_string(tempBuffer, dec128, &flags);
    
    // Allocate and copy the result
    _stringBuffer = new char[strlen(tempBuffer) + 1];
    strcpy(_stringBuffer, tempBuffer);
    
    return _stringBuffer;
}

// Create a Decimal128 from a string
Decimal128Wrapper* Decimal128Wrapper::fromString(const char* str) {
    uint32_t flags = 0;
    BID_UINT128 dec128 = bid128_from_string(const_cast<char*>(str), 0, &flags);
    return new Decimal128Wrapper(Value{dec128.w[0], dec128.w[1]});
}

// Create a Decimal128 from an int64
Decimal128Wrapper* Decimal128Wrapper::fromInt64(int64_t value) {
    uint32_t flags = 0;
    BID_UINT128 dec128 = bid64_to_bid128(value, &flags);
    return new Decimal128Wrapper(Value{dec128.w[0], dec128.w[1]});
}
