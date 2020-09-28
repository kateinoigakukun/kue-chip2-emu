enum Inst: Equatable {
    /// NOP
    case nop
    /// HLT
    case halt
    /// OUT
    case output
    /// IN
    case input
    /// RCF
    case resetCF
    /// SCF
    case setCF
    /// Bcc
    case branch(BranchCondition)
    /// Ssm
    case shift(Register, ShiftMode)
    // Rsm
    case rotate(Register, ShiftMode)
    /// LD
    case load(Register, LoadAddressMode)
    /// ST
    case store(Register, StoreAddressMode)
    /// SBC
    case subWithCarry(Register, LoadAddressMode)
    /// ADC
    case addWithCarry(Register, LoadAddressMode)
    /// SUB
    case sub(Register, LoadAddressMode)
    /// ADD
    case add(Register, LoadAddressMode)
    /// EOR
    case eor(Register, LoadAddressMode)
    /// OR
    case or(Register, LoadAddressMode)
    /// AND
    case and(Register, LoadAddressMode)
    /// CPM
    case cmp(Register, LoadAddressMode)

    init?(rawValue: UInt8) {
        let leftBits = (rawValue & 0xF0) >> 4
        let rightBits = rawValue & 0x0F
        let firstBitMask: UInt8 = 0x8
        let rightFirstBit = (rightBits & firstBitMask) >> 3
        switch leftBits {
        case 0:
            self = (rightBits & firstBitMask == 0) ? .nop : .halt
        case 5:
            self = .halt
        case 1:
            self = (rightBits & firstBitMask == 0) ? .output : .input
        case 2:
            self = (rightBits & firstBitMask == 0) ? .resetCF : .setCF
        case 3:
            guard let cond = BranchCondition(rawValue: rightBits) else {
                return nil
            }
            self = .branch(cond)
        case 4:
            let register = Register(rawValue: rightFirstBit)!
            let isShift = (rightBits & 0x04) == 0
            guard let mode = ShiftMode(rawValue: rightBits & 0x03) else {
                return nil
            }
            self = isShift ? .shift(register, mode) : .rotate(register, mode)
        case 6:
            let register = Register(rawValue: rightFirstBit)!
            guard let mode = LoadAddressMode(rawValue: rightBits & ~firstBitMask) else {
                return nil
            }
            self = .load(register, mode)
        case 7:
            let register = Register(rawValue: rightFirstBit)!
            guard let mode = StoreAddressMode(rawValue: rightBits & ~firstBitMask) else {
                return nil
            }
            self = .store(register, mode)
        default:
            let constructorMap: [UInt8: (Register, LoadAddressMode) -> Inst] = [
                8: Inst.subWithCarry,
                9: Inst.addWithCarry,
                10: Inst.sub,
                11: Inst.add,
                12: Inst.eor,
                13: Inst.or,
                14: Inst.and,
                15: Inst.cmp,
            ]
            guard let constructor = constructorMap[leftBits] else {
                return nil
            }
            let register = Register(rawValue: rightFirstBit)!
            guard let mode = LoadAddressMode(rawValue: rightBits & ~firstBitMask) else {
                return nil
            }
            self = constructor(register, mode)
        }
    }
}

extension Inst {
    enum BranchCondition: UInt8 {
        /// A
        case always = 0
        /// VF ( VF = 1 )
        case onOverFlow = 8
        /// NZ ( != 0 )
        case onNotZero = 1
        /// Z ( == 0 )
        case onZero = 9
        /// ZP ( >= 0 )
        case onZeroOrPositive = 2
        /// N ( < 0 )
        case onNegative = 10
        case onPositive = 3
        case onZeroOrNegative = 11
        case onNoInput = 4
        case onNoOutput = 12
        case onNoCarry = 5
        case onCarry = 13
        case onGreaterThanOrEqual = 6
        case onLessThan = 14
        case onGreaterThan = 7
        case onLessThanOrEqual = 15

        func check(state: State) -> Bool {
            switch self {
            case .always: return true
            case .onOverFlow: return state.flag.vf
            case .onNotZero: return !state.flag.zf
            case .onZero: return state.flag.zf
            case .onZeroOrPositive:
                return !state.flag.nf
            case .onNegative:
                return state.flag.nf
            case .onPositive:
                return !state.flag.nf && !state.flag.zf
            case .onZeroOrNegative:
                return state.flag.nf || state.flag.zf
            case .onNoInput:
                return !state.ibuf.flag
            case .onNoOutput:
                return !state.obuf.flag
            case .onNoCarry:
                return !state.flag.cf
            case .onCarry:
                return state.flag.cf
            case .onGreaterThanOrEqual:
                return !(state.flag.vf ^ state.flag.nf)
            case .onLessThan:
                return state.flag.vf ^ state.flag.nf
            case .onGreaterThan:
                return !((state.flag.vf ^ state.flag.nf) || state.flag.zf)
            case .onLessThanOrEqual:
                return (state.flag.vf ^ state.flag.nf) || state.flag.zf
            }
        }
    }

    enum ShiftMode: UInt8 {
        case rightArithmetically = 0x00
        case leftArithmetically = 0x01
        case rightLogically = 0x02
        case leftLogically = 0x03
    }

    enum LoadAddressMode {
        case acc
        case ix
        case immediate
        case absoluteText
        case absoluteData
        case relativeText
        case relativeData

        init?(rawValue: UInt8) {
            switch rawValue {
            case 0:
                self = .acc
            case 1:
                self = .ix
            case 2, 3:
                self = .immediate
            case 4:
                self = .absoluteText
            case 5:
                self = .absoluteData
            case 6:
                self = .relativeText
            case 7:
                self = .relativeData
            default:
                return nil
            }
        }
    }

    enum StoreAddressMode {
        case absoluteText
        case absoluteData
        case relativeText
        case relativeData

        init?(rawValue: UInt8) {
            switch rawValue {
            case 4:
                self = .absoluteText
            case 5:
                self = .absoluteData
            case 6:
                self = .relativeText
            case 7:
                self = .relativeData
            default:
                return nil
            }
        }
    }

    enum Register: UInt8 {
        case acc = 0x00
        case ix = 0x01
    }
}
