//
//  User.swift
//  
//
//  Created by Brandon Plank on 9/22/21.
//

import Vapor
import Fluent
import FluentSQLiteDriver

final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "score")
    var score: Int?
    
    @Field(key: "passwordHash")
    var passwordHash: String
    
    @Field(key: "jailbroken")
    var jailbroken: Bool?

    @Field(key: "hasHackedTools")
    var hasHackedTools: Bool?

    @Field(key: "ranInEmulator")
    var ranInEmulator: Bool?

    @Field(key: "hasModifiedScore")
    var hasModifiedScore: Bool?
    
    @Field(key: "isBanned")
    var isBanned: Bool?
    
    init() { }
    
    init(id: UUID? = UUID(), name: String, score: Int? = 0, passwordHash: String, jailbroken: Bool? = false, hasHackedTools: Bool? = false, ranInEmulator: Bool? = false, hasModifiedScore: Bool? = false, isBanned: Bool? = false) {
        self.id = id
        self.name = name
        self.score = score
        self.passwordHash = passwordHash
        self.jailbroken = jailbroken
        self.hasHackedTools = hasHackedTools
        self.ranInEmulator = ranInEmulator
        self.hasModifiedScore = hasModifiedScore
        self.isBanned = isBanned
    }
}

extension User {
    struct PublicUser: Content {
        var id: UUID?
        var name: String
        var score: Int?

        init(_ user: User) throws {
            self.id = try user.requireID()
            self.name = user.name
            self.score = user.score
        }
    }
}

extension User {
    struct Migration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .id()
                .field("name", .string)
                .field("score", .int)
                .field("passwordHash", .string)
                .field("jailbroken", .bool)
                .field("hasHackedTools", .bool)
                .field("ranInEmulator", .bool)
                .field("hasModifiedScore", .bool)
                .field("isBanned", .bool)
                .unique(on: "name")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users").delete()
        }
    }
}

extension User: Authenticatable { }
