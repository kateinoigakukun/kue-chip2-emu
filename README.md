# KueChip2Emu

kue-chip2 Emulator written in Swift

```swift
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
```
