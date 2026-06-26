struct TestCase: Sendable {
    var name: String
    var run: @Sendable () throws -> Void

    init(_ name: String, _ run: @escaping @Sendable () throws -> Void) {
        self.name = name
        self.run = run
    }
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ label: String,
    file: StaticString = #fileID,
    line: UInt = #line
) throws {
    if !condition() {
        throw TestFailure(label: label, file: String(describing: file), line: line)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    var label: String
    var file: String
    var line: UInt

    var description: String {
        "\(file):\(line): expectation failed: \(label)"
    }
}
