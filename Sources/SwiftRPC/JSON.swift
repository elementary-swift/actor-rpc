import NewCodable

func encodeJSON(_ value: borrowing some JSONEncodable & ~Copyable) throws(CodingError.Encoding) -> [UInt8] {
    try NewJSONEncoder().encode(value) { bytes throws(CodingError.Encoding) in
        Array(copying: .init(viewing: bytes))
    }
}

func decodeJSON<T: JSONDecodable>(_ type: T.Type, from bytes: RawSpan) throws(CodingError.Decoding) -> T {
    try NewJSONDecoder().decode(type, from: bytes)
}

/// A stand-in until NewCodable can decode an array of differently typed elements one by one.
enum JSONArray {
    /// The byte range of each element of a top-level JSON array.
    ///
    /// It only finds the boundaries, so each element can be decoded in place as its own
    /// argument type. The decoder validates what is inside.
    static func elements(of bytes: Span<UInt8>) -> [Range<Int>]? {
        var position = bytes.skippingWhitespace(from: 0)
        guard bytes.has(.openBracket, at: position) else { return nil }
        position = bytes.skippingWhitespace(from: position + 1)

        var elements: [Range<Int>] = []
        if bytes.has(.closeBracket, at: position) {
            position += 1
        } else {
            while true {
                guard let end = bytes.endOfValue(from: position) else { return nil }
                elements.append(position..<end)
                position = bytes.skippingWhitespace(from: end)
                if bytes.has(.comma, at: position) {
                    position = bytes.skippingWhitespace(from: position + 1)
                } else if bytes.has(.closeBracket, at: position) {
                    position += 1
                    break
                } else {
                    return nil
                }
            }
        }

        return bytes.skippingWhitespace(from: position) == bytes.count ? elements : nil
    }
}

extension Span<UInt8> {
    fileprivate func has(_ byte: UInt8, at position: Int) -> Bool {
        position < count && self[position] == byte
    }

    fileprivate func skippingWhitespace(from position: Int) -> Int {
        var position = position
        while position < count, self[position].isJSONWhitespace {
            position += 1
        }
        return position
    }

    /// The end of the value that starts at `start`. Brackets of either kind only count depth.
    fileprivate func endOfValue(from start: Int) -> Int? {
        var position = start
        var depth = 0
        while position < count {
            switch self[position] {
            case .quote:
                guard let end = endOfString(from: position) else { return nil }
                if depth == 0 { return end }
                position = end
                continue
            case .openBracket, .openBrace:
                depth += 1
            case .closeBracket, .closeBrace:
                if depth == 0 { return position > start ? position : nil }
                depth -= 1
                if depth == 0 { return position + 1 }
            case .comma where depth == 0:
                return position > start ? position : nil
            case let byte where depth == 0 && byte.isJSONWhitespace:
                return position
            default:
                break
            }
            position += 1
        }
        return nil
    }

    /// Just past the closing quote of the string whose opening quote is at `start`.
    private func endOfString(from start: Int) -> Int? {
        var position = start + 1
        while position < count {
            switch self[position] {
            case .quote: return position + 1
            case .backslash: position += 2
            default: position += 1
            }
        }
        return nil
    }
}

extension UInt8 {
    fileprivate static let quote = UInt8(ascii: "\"")
    fileprivate static let backslash = UInt8(ascii: "\\")
    static let comma = UInt8(ascii: ",")
    static let openBracket = UInt8(ascii: "[")
    static let closeBracket = UInt8(ascii: "]")
    fileprivate static let openBrace = UInt8(ascii: "{")
    fileprivate static let closeBrace = UInt8(ascii: "}")

    fileprivate var isJSONWhitespace: Bool {
        self == 0x20 || self == 0x0A || self == 0x0D || self == 0x09
    }
}

extension [UInt8] {
    init(copying bytes: Span<UInt8>) {
        self.init(capacity: bytes.count) { output in
            for index in bytes.indices { output.append(bytes[index]) }
        }
    }
}
