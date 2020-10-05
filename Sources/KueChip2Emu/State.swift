@dynamicMemberLookup
struct Flag {
    struct Mask {
        /// Zero Flag
        let zf: UInt8 = 0x01
        /// Negative Flag
        let nf: UInt8 = 0x02
        /// oVerflow Flag
        let vf: UInt8 = 0x04
        /// Carry Flag
        let cf: UInt8 = 0x08
    }

    private static let mask = Mask()
    private(set) var rawValue: UInt8
    subscript(dynamicMember keyPath: KeyPath<Mask, UInt8>) -> Bool {
        get { return (rawValue & Self.mask[keyPath: keyPath]) != 0 }
        set {
            let mask = Self.mask[keyPath: keyPath]
            rawValue = (rawValue & ~mask) | mask * (newValue ? 1 : 0)
        }
    }
}

struct Memory {
    static let programSpace = 0x100
    static let dataSpace = 0x100
    typealias Address = UInt8
    typealias Buffer = [UInt8]
    private var buffer: Buffer
    init(text: [UInt8], data: [UInt8]) {
        buffer = Array(repeating: 0, count: Self.programSpace + Self.dataSpace)
        for (offset, byte) in text.enumerated() {
            buffer[offset] = byte
        }

        for (offset, byte) in data.enumerated() {
            buffer[Self.programSpace + offset] = byte
        }
    }

    subscript(text address: Address) -> UInt8 {
        get { buffer[Buffer.Index(address)] }
        set {
            buffer[Buffer.Index(address)] = newValue
        }
    }

    subscript(data address: Address) -> UInt8 {
        get { buffer[Self.programSpace + Buffer.Index(address)] }
        set {
            buffer[Self.programSpace + Buffer.Index(address)] = newValue
        }
    }

    var data: ArraySlice<UInt8> {
        buffer[Self.programSpace ..< buffer.endIndex]
    }
}

enum Phase {
    case p0, p1, p2, p3, p4
    func next() -> Phase {
        switch self {
        case .p0: return .p1
        case .p1: return .p2
        case .p2: return .p3
        case .p3: return .p4
        case .p4: return .p0
        }
    }
}

struct BufferState {
    var value: UInt8
    var flag: Bool
}

struct State {
    /// ACCumulator
    var acc: UInt8
    /// IndeX register
    var ix: UInt8
    /// Program Counter
    var pc: UInt8
    /// Memory Address Register
    var mar: Memory.Address
    /// Instruction Register
    var ir: Inst
    /// Flag Register
    var flag: Flag
    /// Internal state to indicate processing phase
    var phase: Phase
    /// Memory
    var memory: Memory

    // MARK: - Buffer IO

    /// OBUF
    var obuf: BufferState
    var ibuf: BufferState

    subscript(register register: Inst.Register) -> UInt8 {
        get {
            switch register {
            case .acc: return acc
            case .ix: return ix
            }
        }
        set {
            switch register {
            case .acc: acc = newValue
            case .ix: ix = newValue
            }
        }
    }
}
