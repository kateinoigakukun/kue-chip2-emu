struct KueChip2 {
    enum Error: Swift.Error {
        case invalidInstruction(UInt8)
    }

    enum Signal {
        case halt
    }

    var state: State
    mutating func iteratePhase() throws -> Signal? {
        defer { state.phase = state.phase.next() }
        switch (state.phase, state.ir) {
        case (.p0, _):
            state.mar = state.pc
            state.pc += 1
        case (.p1, _):
            // Copy through DBi (Data Bus for Input)
            let rawInst = state.memory[text: state.mar]
            guard let inst = Inst(rawValue: rawInst) else {
                throw Error.invalidInstruction(rawInst)
            }
            state.ir = inst
            return nil
        case (_, .halt):
            return .halt
        case (_, .nop):
            break

        case (.p2, .output):
            state.obuf.value = state.acc
        case (.p3, .output):
            state.obuf.flag = true
        case (.p4, .output): break

        case (.p2, .input):
            state.acc = state.ibuf.value
        case (.p3, .input):
            state.ibuf.flag = false
        case (.p4, .input): break

        case (.p2, .resetCF):
            state.flag.cf = false
        case (_, .resetCF): break

        case (.p2, .setCF):
            state.flag.cf = true
        case (_, .setCF): break

        case (.p2, .branch):
            state.mar = state.pc
            state.pc += 1
        case let (.p3, .branch(cond)):
            if cond.check(state: state) {
                let destination = state.memory[text: state.mar]
                state.pc = destination
            }
        case (.p4, .branch): break

        case let (.p2, .shift(reg, mode)):
            let value = state[register: reg]
            state[register: reg] = shift(value, mode: mode, flag: &state.flag)
        case let (.p2, .rotate(reg, mode)):
            let value = state[register: reg]
            state[register: reg] = rotate(value, mode: mode, flag: &state.flag)
        case let (.p3, .shift(reg, _)),
             let (.p3, .rotate(reg, _)):
            let result = state[register: reg]
            state.flag.vf = false
            state.flag.nf = (result & 0x80) != 0
            state.flag.zf = result == 0
        case (.p4, .shift), (.p4, .rotate): break

        case let (.p2, .load(reg, addressMode)):
            switch addressMode {
            case .acc:
                state[register: reg] = state[register: .acc]
            case .ix:
                state[register: reg] = state[register: .ix]
            case .immediate,
                 .absoluteText, .absoluteData,
                 .relativeText, .relativeData:
                state.mar = state.pc
                state.pc += 1
            }
        case let (.p3, .load(reg, addressMode)):
            switch addressMode {
            case .acc, .ix: break
            case .immediate:
                state[register: reg] = state.memory[text: state.mar]
            case .absoluteText, .absoluteData:
                state.mar = state.memory[text: state.mar]
            case .relativeText, .relativeData:
                state.mar = state.ix + state.memory[text: state.mar]
            }
        case let (.p4, .load(reg, addressMode)):
            switch addressMode {
            case .acc, .ix, .immediate: break
            case .absoluteText, .relativeText:
                state[register: reg] = state.memory[text: state.mar]
            case .absoluteData, .relativeData:
                state[register: reg] = state.memory[data: state.mar]
            }

        case (.p2, .store):
            state.mar = state.pc
            state.pc += 1
        case let (.p3, .store(_, addressMode)):
            switch addressMode {
            case .absoluteText, .absoluteData:
                state.mar = state.memory[text: state.mar]
            case .relativeText, .relativeData:
                state.mar = state.ix + state.memory[text: state.mar]
            }
        case let (.p4, .store(reg, addressMode)):
            switch addressMode {
            case .absoluteText, .relativeText:
                state.memory[text: state.mar] = state[register: reg]
            case .absoluteData, .relativeData:
                state.memory[data: state.mar] = state[register: reg]
            }

        case let (.p2, .subWithCarry(reg, addressMode)):
            handleBinaryOperationPhase2(.subWithCarry, register: reg, addressMode: addressMode)
        case let (.p2, .addWithCarry(reg, addressMode)):
            handleBinaryOperationPhase2(.addWithCarry, register: reg, addressMode: addressMode)
        case let (.p2, .sub(reg, addressMode)):
            handleBinaryOperationPhase2(.sub, register: reg, addressMode: addressMode)
        case let (.p2, .add(reg, addressMode)):
            handleBinaryOperationPhase2(.add, register: reg, addressMode: addressMode)
        case let (.p2, .eor(reg, addressMode)):
            handleBinaryOperationPhase2(.eor, register: reg, addressMode: addressMode)
        case let (.p2, .or(reg, addressMode)):
            handleBinaryOperationPhase2(.or, register: reg, addressMode: addressMode)
        case let (.p2, .and(reg, addressMode)):
            handleBinaryOperationPhase2(.and, register: reg, addressMode: addressMode)
        case let (.p2, .cmp(reg, addressMode)):
            handleBinaryOperationPhase2(.cmp, register: reg, addressMode: addressMode)

        case let (.p3, .subWithCarry(reg, addressMode)):
            handleBinaryOperationPhase3(.subWithCarry, register: reg, addressMode: addressMode)
        case let (.p3, .addWithCarry(reg, addressMode)):
            handleBinaryOperationPhase3(.addWithCarry, register: reg, addressMode: addressMode)
        case let (.p3, .sub(reg, addressMode)):
            handleBinaryOperationPhase3(.sub, register: reg, addressMode: addressMode)
        case let (.p3, .add(reg, addressMode)):
            handleBinaryOperationPhase3(.add, register: reg, addressMode: addressMode)
        case let (.p3, .eor(reg, addressMode)):
            handleBinaryOperationPhase3(.eor, register: reg, addressMode: addressMode)
        case let (.p3, .or(reg, addressMode)):
            handleBinaryOperationPhase3(.or, register: reg, addressMode: addressMode)
        case let (.p3, .and(reg, addressMode)):
            handleBinaryOperationPhase3(.and, register: reg, addressMode: addressMode)
        case let (.p3, .cmp(reg, addressMode)):
            handleBinaryOperationPhase3(.cmp, register: reg, addressMode: addressMode)

        case let (.p4, .subWithCarry(reg, addressMode)):
            handleBinaryOperationPhase4(.subWithCarry, register: reg, addressMode: addressMode)
        case let (.p4, .addWithCarry(reg, addressMode)):
            handleBinaryOperationPhase4(.addWithCarry, register: reg, addressMode: addressMode)
        case let (.p4, .sub(reg, addressMode)):
            handleBinaryOperationPhase4(.sub, register: reg, addressMode: addressMode)
        case let (.p4, .add(reg, addressMode)):
            handleBinaryOperationPhase4(.add, register: reg, addressMode: addressMode)
        case let (.p4, .eor(reg, addressMode)):
            handleBinaryOperationPhase4(.eor, register: reg, addressMode: addressMode)
        case let (.p4, .or(reg, addressMode)):
            handleBinaryOperationPhase4(.or, register: reg, addressMode: addressMode)
        case let (.p4, .and(reg, addressMode)):
            handleBinaryOperationPhase4(.and, register: reg, addressMode: addressMode)
        case let (.p4, .cmp(reg, addressMode)):
            handleBinaryOperationPhase4(.cmp, register: reg, addressMode: addressMode)
        }
        return nil
    }

    mutating func handleBinaryOperationPhase2(_ operation: BinaryOperation,
                                              register: Inst.Register, addressMode: Inst.LoadAddressMode)
    {
        let base = state[register: register]
        switch addressMode {
        case .acc:
            let value = state[register: .acc]
            let result = operation.compute(
                base: Int8(bitPattern: base), value: Int8(bitPattern: value), flag: &state.flag
            )
            state[register: register] = UInt8(bitPattern: result)
        case .ix:
            let value = state[register: .ix]
            let result = operation.compute(
                base: Int8(bitPattern: base), value: Int8(bitPattern: value), flag: &state.flag
            )
            state[register: register] = UInt8(bitPattern: result)
        case .immediate,
             .absoluteText, .absoluteData,
             .relativeText, .relativeData:
            state.mar = state.pc
            state.pc += 1
        }
    }

    mutating func handleBinaryOperationPhase3(_ operation: BinaryOperation,
                                              register: Inst.Register, addressMode: Inst.LoadAddressMode)
    {
        let base = state[register: register]
        switch addressMode {
        case .acc, .ix: break
        case .immediate:
            let value = state.memory[text: state.mar]
            let result = operation.compute(
                base: Int8(bitPattern: base), value: Int8(bitPattern: value), flag: &state.flag
            )
            state[register: register] = UInt8(bitPattern: result)
        case .absoluteText, .absoluteData:
            state.mar = state.memory[text: state.mar]
        case .relativeText, .relativeData:
            state.mar = state.ix + state.memory[text: state.mar]
        }
    }

    mutating func handleBinaryOperationPhase4(_ operation: BinaryOperation,
                                              register: Inst.Register, addressMode: Inst.LoadAddressMode)
    {
        let base = state[register: register]
        switch addressMode {
        case .acc, .ix, .immediate: break
        case .absoluteText, .relativeText:
            let value = state.memory[text: state.mar]
            let result = operation.compute(
                base: Int8(bitPattern: base), value: Int8(bitPattern: value), flag: &state.flag
            )
            state[register: register] = UInt8(bitPattern: result)
        case .absoluteData, .relativeData:
            let value = state.memory[text: state.mar]
            let result = operation.compute(
                base: Int8(bitPattern: base), value: Int8(bitPattern: value), flag: &state.flag
            )
            state[register: register] = UInt8(bitPattern: result)
        }
    }
}
