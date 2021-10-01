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
    
    @Field(key: "deaths")
    var deaths: Int?
    
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
    
    @Field(key: "banReason")
    var banReason: String?
    
    @Field(key: "admin")
    var admin: Bool?
    
    
    init() { }
    
    init(id: UUID? = UUID(), name: String, score: Int? = 0, deaths: Int? = 0, passwordHash: String, jailbroken: Bool? = false, hasHackedTools: Bool? = false, ranInEmulator: Bool? = false, hasModifiedScore: Bool? = false, isBanned: Bool? = false, banReason: String? = nil, admin: Bool? = false) {
        self.id = id
        self.name = name
        self.score = score
        self.deaths = deaths
        self.passwordHash = passwordHash
        self.jailbroken = jailbroken
        self.hasHackedTools = hasHackedTools
        self.ranInEmulator = ranInEmulator
        self.hasModifiedScore = hasModifiedScore
        self.isBanned = isBanned
        self.banReason = banReason
        self.admin = admin
    }
}

extension User {
    struct PublicUser: Content {
        var id: UUID?
        var name: String
        var score: Int?
        var deaths: Int?

        init(_ user: User) throws {
            self.id = try user.requireID()
            self.name = user.name
            self.score = user.score
            self.deaths = user.deaths
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
                .field("deaths", .int)
                .field("passwordHash", .string)
                .field("jailbroken", .bool)
                .field("hasHackedTools", .bool)
                .field("ranInEmulator", .bool)
                .field("hasModifiedScore", .bool)
                .field("isBanned", .bool)
                .field("banReason", .string)
                .field("admin", .bool)
                .unique(on: "name")
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users").delete()
        }
    }
}

extension User: Authenticatable { }
