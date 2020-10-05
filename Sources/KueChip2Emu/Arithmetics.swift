func shift(_ value: UInt8, mode: Inst.ShiftMode, flag: inout Flag) -> UInt8 {
    var result: UInt8
    switch mode {
    case .rightArithmetically:
        result = value >> 1
        let sign = (value & 0x80)
        result |= sign
        flag.cf = (value & 0x1) != 0
    case .leftArithmetically:
        result = value << 1
        let sign = (value & 0x80)
        result |= sign
        flag.cf = (value & 0x80) != 0
    case .rightLogically:
        result = value >> 1
        flag.cf = (value & 0x01) != 0
    case .leftLogically:
        result = value << 1
        flag.cf = (value & 0x80) != 0
    }
    return result
}

func rotate(_ value: UInt8, mode: Inst.ShiftMode, flag: inout Flag) -> UInt8 {
    var result: UInt8
    let rawCF: UInt8 = flag.cf ? 1 : 0
    switch mode {
    case .rightArithmetically:
        result = value >> 1
        result |= rawCF << 7
        flag.cf = (value & 0x1) != 0
    case .leftArithmetically:
        result = value << 1
        result |= rawCF
        flag.cf = (value & 0x80) != 0
    case .rightLogically:
        result = value >> 1
        let lastBit = value & 0x01
        result |= lastBit << 7
        flag.cf = lastBit != 0
    case .leftLogically:
        result = value << 1
        let firstBit = value & 0x80
        result |= firstBit >> 7
        flag.cf = firstBit != 0
    }
    return result
}

enum BinaryOperation {
    /// SBC
    case subWithCarry
    /// ADC
    case addWithCarry
    /// SUB
    case sub
    /// ADD
    case add
    /// EOR
    case eor
    /// OR
    case or
    /// AND
    case and
    /// CPM
    case cmp

    func compute(base: Int8, value: Int8, flag: inout Flag) -> Int8 {
        let rawCF: Int16 = flag.cf ? 1 : 0
        let unsignedBase = Int16(UInt8(bitPattern: base))
        let unsignedValue = Int16(UInt8(bitPattern: value))
        let result: Int8
        defer {
            flag.zf = result == 0
            flag.nf = result < 0
        }
        let largeResult: Int16
        var isOverflow: Bool {
            let signedResult = Int8(bitPattern: UInt8(largeResult & 0xFF))
            return ((base > 0) && (value > 0) && signedResult < 0) ||
                ((base < 0) && (value < 0) && signedResult > 0)
        }
        switch self {
        case .subWithCarry:
            largeResult = unsignedBase - (unsignedValue - rawCF)
            flag.vf = isOverflow
            flag.cf = (largeResult & ~0xFF) != 0
        case .addWithCarry:
            largeResult = unsignedBase + (unsignedValue + rawCF)
            flag.vf = isOverflow
            flag.cf = (largeResult & ~0xFF) != 0
        case .sub:
            largeResult = unsignedBase - unsignedValue
            flag.vf = isOverflow
        case .add:
            largeResult = unsignedBase + unsignedValue
            flag.vf = isOverflow
        case .eor:
            largeResult = unsignedBase ^ unsignedValue
            flag.vf = false
        case .or:
            largeResult = unsignedBase | unsignedValue
            flag.vf = false
        case .and:
            largeResult = unsignedBase & unsignedValue
            flag.vf = false
        case .cmp:
            largeResult = unsignedBase - unsignedValue
            flag.vf = isOverflow
        }

        result = Int8(bitPattern: UInt8(largeResult & 0xFF))
        return result
    }
}
