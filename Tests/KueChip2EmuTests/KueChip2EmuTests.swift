@testable import KueChip2Emu
import XCTest

final class KueChip2EmuTests: XCTestCase {
    func testFlagSet() {
        var flag = Flag(rawValue: 0)
        XCTAssertFalse(flag.cf)
        flag.cf = true
        XCTAssertTrue(flag.cf)
        flag.cf = false
        XCTAssertFalse(flag.cf)
    }

    func testArithmeticRightShift() {
        typealias TestCase = (input: UInt8, output: UInt8, carry: Bool, line: UInt)
        let testCases: [TestCase] = [
            (2, 1, false, #line),
            (4, 2, false, #line),
            (126, 63, false, #line),
            (127, 63, true, #line),
            (UInt8(bitPattern: -2), UInt8(bitPattern: -1), false, #line),
            (UInt8(bitPattern: -4), UInt8(bitPattern: -2), false, #line),
            (UInt8(bitPattern: -128), UInt8(bitPattern: -64), false, #line),
        ]
        for testCase in testCases {
            var flag = Flag(rawValue: 0)
            let result = shift(testCase.input, mode: .rightArithmetically, flag: &flag)
            XCTAssertEqual(result, testCase.output, line: testCase.line)
            XCTAssertEqual(flag.cf, testCase.carry, line: testCase.line)
        }
    }

    func testArithmeticLeftShift() {
        typealias TestCase = (input: UInt8, output: UInt8, carry: Bool, line: UInt)
        let testCases: [TestCase] = [
            (1, 2, false, #line),
            (2, 4, false, #line),
            (64, 128, false, #line),
            (UInt8(bitPattern: -1), UInt8(bitPattern: -2), true, #line),
            (UInt8(bitPattern: -2), UInt8(bitPattern: -4), true, #line),
            (UInt8(bitPattern: -64), UInt8(bitPattern: -128), true, #line),
        ]
        for testCase in testCases {
            var flag = Flag(rawValue: 0)
            let result = shift(testCase.input, mode: .leftArithmetically, flag: &flag)
            XCTAssertEqual(result, testCase.output, line: testCase.line)
            XCTAssertEqual(flag.cf, testCase.carry, line: testCase.line)
        }
    }

    func testArithmeticRightRotate() {
        typealias TestCase = (input: UInt8, output: UInt8, carryIn: Bool, carryOut: Bool, line: UInt)
        let testCases: [TestCase] = [
            (0x0, 0x0, false, false, #line),
            (0x1, 0x0, false, true, #line),
            (0x1, UInt8(bitPattern: -128), true, true, #line),
            (0x41, 0xA0, true, true, #line),
            (UInt8(bitPattern: -1), UInt8(bitPattern: -1), true, true, #line),
        ]
        for testCase in testCases {
            var flag = Flag(rawValue: 0)
            flag.cf = testCase.carryIn
            let result = rotate(testCase.input, mode: .rightArithmetically, flag: &flag)
            XCTAssertEqual(result, testCase.output, line: testCase.line)
            XCTAssertEqual(flag.cf, testCase.carryOut, line: testCase.line)
        }
    }

    func testArithmeticLeftRotate() {
        typealias TestCase = (input: UInt8, output: UInt8, carryIn: Bool, carryOut: Bool, line: UInt)
        let testCases: [TestCase] = [
            (0x0, 0x0, false, false, #line),
            (0x0, 0x1, true, false, #line),
            (UInt8(bitPattern: -128), 0x1, true, true, #line),
            (0xA0, 0x41, true, true, #line),
            (UInt8(bitPattern: -1), UInt8(bitPattern: -1), true, true, #line),
        ]
        for testCase in testCases {
            var flag = Flag(rawValue: 0)
            flag.cf = testCase.carryIn
            let result = rotate(testCase.input, mode: .leftArithmetically, flag: &flag)
            XCTAssertEqual(result, testCase.output, line: testCase.line)
            XCTAssertEqual(flag.cf, testCase.carryOut, line: testCase.line)
        }
    }

    func testAddWithCarry() {
        typealias TestCase = (
            base: Int8, value: Int8, output: Int8,
            carryIn: Bool, flag: UInt8,
            line: UInt
        )
        let testCases: [TestCase] = [
            (126, 2, -128, false, 0x6, #line),
            (126, -126, 0, false, 0x9, #line),
            (-127, -1, -128, false, 0xA, #line),
            (-127, -2, 127, false, 0xC, #line),
            (2, 3, 5, false, 0x0, #line),
        ]
        for testCase in testCases {
            var flag = Flag(rawValue: 0)
            flag.cf = testCase.carryIn
            let result = BinaryOperation.addWithCarry.compute(
                base: testCase.base, value: testCase.value, flag: &flag
            )
            XCTAssertEqual(result, testCase.output, line: testCase.line)
            XCTAssertEqual(flag.rawValue, testCase.flag, line: testCase.line)
        }
    }

    func testDecodeInst() {
        XCTAssertEqual(Inst(rawValue: 0x6A), Inst.load(.ix, .immediate))
    }

    func test8BitLED() throws {
        let bytes: [UInt8] = [0x6A, 0x09, 0x62, 0x01, 0x10, 0x47, 0xAA, 0x01, 0x33, 0x04, 0x0F]
        let flag = Flag(rawValue: 0)
        let memory = Memory(text: bytes, data: [])
        let obuf = BufferState(value: 0, flag: false)
        let ibuf = BufferState(value: 0, flag: false)
        let state = State(
            acc: 0, ix: 0, pc: 0, mar: 0, ir: .nop, flag: flag,
            phase: .p0, memory: memory, obuf: obuf, ibuf: ibuf
        )
        var vm = KueChip2(state: state)
        var ledBits: [UInt8] = []
        while try vm.iteratePhase() != .halt {
            if vm.state.phase == .p4, vm.state.ir == .output {
                ledBits.append(vm.state.obuf.value)
            }
        }
        XCTAssertEqual(ledBits, [1, 2, 4, 8, 16, 32, 64, 128, 1])
    }

    func testStore() throws {
        let bytes: [UInt8] = [0x6a, 0x80, 0x62, 0x01, 0x77, 0x00, 0x0f]
        let flag = Flag(rawValue: 0)
        let memory = Memory(text: bytes, data: [])
        let obuf = BufferState(value: 0, flag: false)
        let ibuf = BufferState(value: 0, flag: false)
        let state = State(
            acc: 0, ix: 0, pc: 0, mar: 0, ir: .nop, flag: flag,
            phase: .p0, memory: memory, obuf: obuf, ibuf: ibuf
        )
        var vm = KueChip2(state: state)
        while try vm.iteratePhase() != .halt {}
        XCTAssertEqual(vm.state.memory[data: 0x80], 1)
    }
}
