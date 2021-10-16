import Vapor
import Fluent
import Leaf
import FluentSQLiteDriver
import Gatekeeper

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    //app.middleware.use(UserAuthenticator())
    
    app.caches.use(.memory)
    
    app.gatekeeper.config = .init(maxRequests: 5, per: .hour)
    
    app.databases.use(.sqlite(.file("flappybird.sqlite")), as: .sqlite)
    app.migrations.add(User.Migration())
    app.migrations.add(Token.Migration())
    
    app.views.use(.leaf)
    
    // register routes
    try routes(app)
}
