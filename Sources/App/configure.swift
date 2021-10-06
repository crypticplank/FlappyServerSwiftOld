import Vapor
import Fluent
import Leaf
import FluentSQLiteDriver
import Gatekeeper
import SimpleFileLogger

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    //app.middleware.use(UserAuthenticator())
    
    services.register(SimpleFileLogger.self)
    config.prefer(SimpleFileLogger.self, for: Logger.self)
    
    app.caches.use(.memory)
    
    app.gatekeeper.config = .init(maxRequests: 1, per: .hour)
    
    app.databases.use(.sqlite(.file("flappybird.sqlite")), as: .sqlite)
    app.migrations.add(User.Migration())
    
    app.views.use(.leaf)
    
    // register routes
    try routes(app)
}
