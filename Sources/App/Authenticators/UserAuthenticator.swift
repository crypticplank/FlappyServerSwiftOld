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
        var score: String
        var time: String
    }
}

extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$name
    static let passwordHashKey = \User.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}
