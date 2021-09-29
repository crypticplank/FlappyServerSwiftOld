//
//  Encryption.swift
//
//  Created by Brandon Plank on 9/29/21.
//

import Foundation
import CryptoSwift


extension String {
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

extension Int64 {
    func addrByteArray() -> [UInt8] {
        let data: Data? = withUnsafeBytes(of: self) { Data($0) }
        let byte = [UInt8](data!)
        return byte
    }
}

extension UInt8 {
    var char: Character {
        return Character(UnicodeScalar(self))
    }
}

extension Int {
    var char: Character {
        return Character(UnicodeScalar(self)!)
    }
}

extension String {
    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }
}

extension StringProtocol {
    var hexaData: Data { .init(hexa) }
    var hexaBytes: [UInt8] { .init(hexa) }
    private var hexa: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { startIndex in
            guard startIndex < self.endIndex else { return nil }
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}

struct KeyIV {
    let Key: [UInt8]
    let IV: [UInt8]
}

class Encryption {
    
    public static let global_key = "1315fcbab2160a8ec57ddec5d089a9ba3e11153bd12e444b6544d1f087ebbef31e4feef25bae5730ec4ae7d7bdda4c18"
    
    static let KeyStruct = convertKeyIvToType(global_key)
    
    public static func convertKeyIvToType(_ keyiv: String) -> KeyIV? {
        if keyiv.count < 96 || keyiv.count > 97 { print("Input a valid keyiv"); return nil }
        let keyString = String(keyiv.prefix(64)) // First 64 letters (32 bytes)
        let ivString = String(keyiv.suffix(32)) // Last 32 letters (16 bytes)
        return KeyIV(Key: keyString.hexaBytes, IV: ivString.hexaBytes)
    }
    
    public static func encrypt(keyiv: KeyIV? = KeyStruct, data: Data) -> Data? {
        guard let keyiv = keyiv else {
            return nil
        }
        do {
            let aes = try AES(key: keyiv.Key, blockMode: CBC(iv: keyiv.IV), padding: .pkcs7)
            return try Data(aes.encrypt([UInt8](data)))
        } catch {
            print("Error encrypting data.")
            return nil
        }
    }
    
    public static func decrypt(keyiv: KeyIV? = KeyStruct, data: Data) -> Data? {
        guard let keyiv = keyiv else {
            return nil
        }
        do {
            let aes = try AES(key: keyiv.Key, blockMode: CBC(iv: keyiv.IV), padding: .pkcs7)
            return try Data(aes.decrypt([UInt8](data)))
        } catch {
            print("Error decrypting data.")
            return nil
        }
    }
    
    public static func encryptBase64(_ any: Any) -> String? {
        let data = withUnsafeBytes(of: any) { Data($0) }
        let encrypted = Encryption.encrypt(data: data)
        return encrypted!.base64EncodedString()
    }
    
    public static func decryptInt(base64: String) -> Int? {
        let sg1 = Data(base64Encoded: base64)!
        let sg2 = Encryption.decrypt(data: sg1)!
        return Int(littleEndian: sg2.withUnsafeBytes { $0.pointee })
    }
    
    public static func genRandomKeyIv() -> KeyIV? {
        do {
            let password: [UInt8] = Array(String().randomString(length: 10).utf8)
            let salt: [UInt8] = Array("flappybirdisthebest".utf8)
            
            let key = try PKCS5.PBKDF2(
                password: password,
                salt: salt,
                iterations: 4096,
                keyLength: 32, /* AES-256 */
                variant: .sha2(.sha256)
            ).calculate()
            
            let iv = AES.randomIV(AES.blockSize)
            
            let ivString = iv.map { String(format: "%02x", $0) }.joined(separator: "")
            let keyString = key.map { String(format: "%02x", $0) }.joined(separator: "")
            let keyiv = "\(keyString)\(ivString)"
            print(keyiv)
            return KeyIV(Key: key, IV: iv)
        } catch {
            print("Error encrypting data.")
            return nil
        }
    }
    
//    public func encryptUsingMasterKey() -> Data? {
//        do {
//            let password: [UInt8] = Array(String().randomString(length: 10).utf8)
//            let salt: [UInt8] = Array("plankontop".utf8)
//
//            if key == nil {
//                key = try PKCS5.PBKDF2(
//                    password: password,
//                    salt: salt,
//                    iterations: 4096,
//                    keyLength: 32, /* AES-256 */
//                    variant: .sha256
//                ).calculate()
//            }
//
//            if iv == nil {
//                iv = AES.randomIV(AES.blockSize)
//            }
//
//            ivString = iv!.map { String(format: "%02x", $0) }.joined(separator: "")
//            keyString = key!.map { String(format: "%02x", $0) }.joined(separator: "")
//            keyiv = "\(keyString!)\(ivString!)"
//
//            let aes = try AES(key: key!, blockMode: CBC(iv: iv!), padding: .pkcs7)
//            data = try Data(aes.encrypt([UInt8](data)))
//        } catch {
//            print("Error encrypting data.")
//            return nil
//        }
//    }
    
//    static let global_key [UInt8]?
//    static let global_iv: [UInt8]?
}

