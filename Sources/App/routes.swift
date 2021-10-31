/*
BSD 3-Clause License

Copyright (c) 2021, Brandon Plank
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import Vapor
import FluentSQL
import Fluent
import Leaf
import Gatekeeper
import FlappyEncryption

struct mainVars: Codable {
    let users: [User]
    let players: Int
    let deaths: Int
}

func routes(_ app: Application) throws {
    app.get { req -> EventLoopFuture<View> in
        return User.query(on: req.db)
            .sort(\.$score, .descending)
            .filter(\.$isBanned == false)
            .range(..<25)
            .all()
            .flatMap{ users -> EventLoopFuture<View> in
                return User.query(on: req.db).filter(\.$isBanned == false).count().flatMap { playerCount -> EventLoopFuture<View> in
                    return User.query(on: req.db).sum(\.$deaths).flatMap { deaths -> EventLoopFuture<View> in
                        let vars = mainVars(users: users, players: playerCount, deaths: deaths!)
                        return req.view.render("main", vars)
                    }
                }
            }
    }
    
    app.get("admin") { req -> EventLoopFuture<View> in
        return req.view.render("admin")
    }
    
    app.get("users") { req in
        return User.query(on: req.db).all().flatMapThrowing { users in
            return try users.map(User.PublicUser.init)
        }
    }
    
    app.get("bans") { req -> EventLoopFuture<View> in
        return User.query(on: req.db)
            .filter(\.$isBanned == true)
            .all()
            .flatMap{ users in
                return req.view.render("bans", ["users": users])
            }
    }
    
    app.get("user", ":name") { req -> EventLoopFuture<View> in
        let name = req.parameters.get("name")
        return User.query(on: req.db)
            .filter(\.$name == name!)
            .first()
            .flatMap { user -> EventLoopFuture<View> in
                return req.view.render("user", ["user": user])
            }
    }
    
    app.get("getID", ":name") { req -> EventLoopFuture<String> in
        let name = req.parameters.get("name")
        return User.query(on: req.db)
            .filter(\.$name == name!)
            .first()
            .flatMapThrowing { user -> String in
                guard let user = user else {
                    throw Abort(.badRequest, reason: "Failed to get actual user.");
                }
                
                guard let id = user.id?.uuidString else {
                    throw Abort(.badRequest, reason: "Failed to unwrap user uuid?");
                }
                return id
            }
    }
    
    app.get("leaderboard", ":amount") { req -> EventLoopFuture<[User.PublicUser]> in
        let amount: Int = req.parameters.get("amount") ?? 100
        return User.query(on: req.db)
            .sort(\.$score, .descending)
            .filter(\.$isBanned == false)
            .range(..<amount)
            .all()
            .flatMapThrowing { users in
                return try users.map(User.PublicUser.init)
            }
    }
    
    app.get("globalDeaths") { req -> EventLoopFuture<Int> in
        return User.query(on: req.db)
            .sum(\.$deaths)
            .map { deaths -> Int in
                return deaths!
            }
    }
    
    app.get("userCount") { req -> EventLoopFuture<Int> in
        return User.query(on: req.db)
            .filter(\.$isBanned == false)
            .count()
    }
    
    let rateLimitedRoute = app.grouped(GatekeeperMiddleware())
    
    rateLimitedRoute.post("registerUser") { req -> User.PublicUser in
        try User.Create.validate(content: req)
        let create = try req.content.decode(User.Create.self)
                              
        if create.name.count > 15 {
            throw Abort(.badRequest, reason: "Your name may not be longer that 15 characters.")
        }
                              
        guard create.password == create.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords did not match")
        }
        
        let user = try User(
            name: create.name,
            passwordHash: Bcrypt.hash(create.password)
        )
        let _ = user.save(on: req.db)
            .map { user }
        req.logger.info("\(user.name) signed up")
        return try User.PublicUser(user)
    }
    
    let passwordProtected = app.grouped([User.authenticator(), Token.authenticator()])
    
    passwordProtected.post("login") { req -> User.PublicUser in
        let user = try req.auth.require(User.self)
        req.logger.info("\(user.name) logging in")
        
        return try User.PublicUser(user)
    }
    
    passwordProtected.post("submitDeath") { req -> String in
        let user = try req.auth.require(User.self)
        user.deaths! += 1
        let _ = user.update(on: req.db) .map { user }
        throw Abort(.accepted)
    }
    
    // Hacking endpoints
    
    passwordProtected.post("isJailbroken") { req -> EventLoopFuture<String> in
        let user = try req.auth.require(User.self)
        user.jailbroken = true
        let _ = user.update(on: req.db) .map { user }
        throw Abort(.accepted)
    }
    
    passwordProtected.post("emulator") { req -> EventLoopFuture<String> in
        let user = try req.auth.require(User.self)
        user.ranInEmulator = true
        let _ = user.update(on: req.db) .map { user }
        throw Abort(.accepted)
    }
    
    passwordProtected.post("hasHackedTools") { req -> EventLoopFuture<String> in
        let user = try req.auth.require(User.self)
        user.hasHackedTools = true
        let _ = user.update(on: req.db) .map { user }
        throw Abort(.accepted)
    }
    
    // End Hacking endpoinbs
    
    passwordProtected.post("submitScore") { req -> EventLoopFuture<String> in
        let user = try req.auth.require(User.self)
        
        var score: User.SubmitScore? = nil
        do {
            score = try req.content.decode(User.SubmitScore.self)
        } catch {
            req.logger.error("Unable to decode score for \(user.name), possibly using older version.")
        }
        
        guard let score = score else {
            throw Abort(.badRequest)
        }
        
        if !FlappyEncryption.verify(score.score, score.time, score.verify) {
            req.logger.error("Hashs did not match, expected: \(FlappyEncryption.genHash(score.score, score.time)), got: \(score.verify)")
            throw Abort(.badRequest, reason: "Unable to verify score")
        }
        
        req.logger.info("Score verification passed: \(score.verify)")
        
        req.logger.info("User: \(user.name.description)[ID:\(user.id!.description)] submitted score: \(score.score), took \(score.time) seconds.")

        if (score.time + 100 < score.score || score.time - 100 > score.score) /* && score > 1000 */ {
             user.isBanned = true
             user.banReason = "Cheating (Anticheat)"
             let _ = user.update(on: req.db) .map { user }
         }
        
        if score.score > user.score! {
            user.score = score.score
            let _ = user.update(on: req.db) .map { user }
            req.logger.info("Processed score for \(user.name.description)")
        }
        throw Abort(.accepted)
    }
    
    // Admin Things
    
    passwordProtected.get("internal_users") { req -> EventLoopFuture<[User]> in
        let user = try req.auth.require(User.self)
        if user.admin! {
            return User.query(on: req.db).all()
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("unban", ":userID") { req -> EventLoopFuture<String> in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            let ret = User.find(uuid, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { readUser -> String in
                req.logger.info("\(user.name) requested to unban \(readUser.name)")
                if !user.owner! {
                    if user.admin! && readUser.admin! || readUser.owner! {
                        throw Abort(.unauthorized, reason: "Cannot unban another admin")
                    }
                }
                readUser.isBanned = false
                readUser.banReason = nil
                _ = readUser.save(on: req.db)
                throw Abort(.accepted, reason: "User has been unbanned")
            }
            return ret
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("ban", ":userID", ":reason") { req -> EventLoopFuture<String> in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            let reason = req.parameters.get("reason")!
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            let ret = User.find(uuid, on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMapThrowing { readUser -> String in
                    req.logger.info("\(user.name) requested to ban \(readUser.name)")
                    if !user.owner! {
                        if user.admin! && readUser.admin! || readUser.owner! {
                            throw Abort(.unauthorized, reason: "Cannot ban another admin")
                        }
                    }
                    
                    readUser.isBanned = true
                    readUser.banReason = reason
                    _ = readUser.save(on: req.db)
                    throw Abort(.accepted, reason: "User has been banned")
                }
            return ret
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("restoreScore", ":userID", ":score") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            let score: Int = req.parameters.get("score") ?? 0
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            _ = User.find(uuid, on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { readUser -> EventLoopFuture<Void> in
                    readUser.score = score
                    return readUser.save(on: req.db)
                }
            throw Abort(.accepted, reason: "Restored score to \(score)")
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("delete", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.admin! {
            let id = req.parameters.get("userID")!
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            _ = User.query(on: req.db)
                .filter(\.$id == uuid)
                .first()
                .flatMapThrowing { readUser in
                    guard let readUser = readUser else {
                        throw Abort(.badRequest)
                    }
                    if !user.owner! {
                        if user.admin! && readUser.admin! || readUser.owner! {
                            throw Abort(.unauthorized, reason: "Cannot delete another admin")
                        }
                    }
                    _ = user.delete(on: req.db)
                }
            
            throw Abort(.accepted, reason: "User has been removed")
        } else {
            throw Abort(.unauthorized)
        }
    }
    
    passwordProtected.get("makeAdmin", ":userID") { req -> String in
        let user = try req.auth.require(User.self)
        if user.owner! {
            let id = req.parameters.get("userID")!
            
            guard let uuid = UUID(uuidString: id) else {
                throw Abort(.badRequest, reason: "Not a valid uuid")
            }
            
            _ = User.find(uuid, on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { readUser -> EventLoopFuture<Void> in
                    readUser.admin = true
                    return readUser.save(on: req.db)
                }
            
            throw Abort(.accepted, reason: "User has been removed")
        } else {
            throw Abort(.unauthorized)
        }
    }
}
