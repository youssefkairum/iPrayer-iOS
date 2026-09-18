//
//  ZipArchive.swift
//  iPrayer
//
//  A minimal ZIP reader, enough for the surah archives the audio host publishes: a flat list of files,
//  stored or deflated, well under 4 GB. iOS has no public ZIP API, and a full library would be overkill.
//

import Foundation
import Compression
import zlib

nonisolated enum ZipArchive {
    struct Entry {
        let name: String
        let method: UInt16          // 0 = stored, 8 = deflate
        let crc32: UInt32
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }
    
    enum ZipError: Error { case notAZip, corrupt, unsupportedMethod(UInt16), checksumMismatch(String) }
    
    /// Reads the central directory at the end of the archive.
    static func entries(in data: Data) throws -> [Entry] {
        // End of central directory record: signature 0x06054b50, at most 65535 bytes of comment after it
        guard data.count >= 22 else { throw ZipError.notAZip }
        var eocd = -1
        var position = data.count - 22
        let stopAt = max(0, data.count - 22 - 65535)
        while position >= stopAt {
            if u32(data, position) == 0x06054b50 { eocd = position; break }
            position -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }
        
        let entryCount = Int(u16(data, eocd + 10))
        let directoryOffset = Int(u32(data, eocd + 16))
        
        var entries: [Entry] = []
        var cursor = directoryOffset
        for _ in 0..<entryCount {
            guard cursor + 46 <= data.count, u32(data, cursor) == 0x02014b50 else { throw ZipError.corrupt }
            let method = u16(data, cursor + 10)
            let crc = u32(data, cursor + 16)
            let compressed = Int(u32(data, cursor + 20))
            let uncompressed = Int(u32(data, cursor + 24))
            let nameLength = Int(u16(data, cursor + 28))
            let extraLength = Int(u16(data, cursor + 30))
            let commentLength = Int(u16(data, cursor + 32))
            let localOffset = Int(u32(data, cursor + 42))
            guard cursor + 46 + nameLength <= data.count else { throw ZipError.corrupt }
            let name = String(decoding: data[(cursor + 46)..<(cursor + 46 + nameLength)], as: UTF8.self)
            entries.append(Entry(name: name, method: method, crc32: crc, compressedSize: compressed, uncompressedSize: uncompressed, localHeaderOffset: localOffset))
            cursor += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }
    
    /// The file's bytes, verified against the archive's checksum.
    static func extract(_ entry: Entry, from data: Data) throws -> Data {
        let header = entry.localHeaderOffset
        guard header + 30 <= data.count, u32(data, header) == 0x04034b50 else { throw ZipError.corrupt }
        let nameLength = Int(u16(data, header + 26))
        let extraLength = Int(u16(data, header + 28))
        let start = header + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= data.count else { throw ZipError.corrupt }
        let compressed = data.subdata(in: start..<(start + entry.compressedSize))
        
        let bytes: Data
        switch entry.method {
        case 0:
            bytes = compressed
        case 8:
            bytes = try inflate(compressed, expectedSize: entry.uncompressedSize)
        default:
            throw ZipError.unsupportedMethod(entry.method)
        }
        
        let checksum = bytes.withUnsafeBytes { buffer -> UInt32 in
            UInt32(zlib.crc32(0, buffer.bindMemory(to: Bytef.self).baseAddress, uInt(buffer.count)))
        }
        guard checksum == entry.crc32 else { throw ZipError.checksumMismatch(entry.name) }
        return bytes
    }
    
    private static func inflate(_ input: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { destination -> Int in
            input.withUnsafeBytes { source -> Int in
                // COMPRESSION_ZLIB is raw DEFLATE, which is what ZIP entries contain
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                    source.bindMemory(to: UInt8.self).baseAddress!, input.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == expectedSize else { throw ZipError.corrupt }
        return output
    }
    
    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[data.startIndex + offset]) | UInt16(data[data.startIndex + offset + 1]) << 8
    }
    
    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(u16(data, offset)) | UInt32(u16(data, offset + 2)) << 16
    }
}
