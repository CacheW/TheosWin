// Pure Swift logic exported with C ABI — callable from ObjC/C, no framework imports.
@_cdecl("vanta_swift_add")
public func vanta_swift_add(_ a: Int32, _ b: Int32) -> Int32 { return a + b }

@_cdecl("vanta_swift_fib")
public func vanta_swift_fib(_ n: Int32) -> Int32 {
    if n < 2 { return n }
    var a: Int32 = 0, b: Int32 = 1
    for _ in 2...n { (a, b) = (b, a &+ b) }
    return b
}
