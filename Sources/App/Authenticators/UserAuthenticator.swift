//
//  UserAuthenticator.swift
//
//
//  Created by Brandon Plank on 9/25/21.
//

import Vapor
import FluentKit
import Fluent

extension User {
    struct Create: Content {
        var name: String
        var password: String
        var confirmPassword: String
    }
    
    struct SubmitScore: Content {
        var score: Int
        var time: Int
        var verify: String
    }
}

extension User {
    func createToken(source: SessionSource) throws -> Token {
        let calendar = Calendar(identifier: .gregorian)
        let expiryDate = calendar.date(byAdding: .year, value: 1, to: Date())
        return try Token(userId: requireID(), token: [UInt8].random(count: 16).base64, source: source, expiresAt: expiryDate)
    }
}

extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(8...) && .alphanumeric)
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$name
    static let passwordHashKey = \User.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension Token: ModelTokenAuthenticatable {
  static let valueKey = \Token.$value
  static let userKey = \Token.$user

  var isValid: Bool {
    guard let expiryDate = expiresAt else {
      return true
    }
    
    return expiryDate > Date()
  }
}

