import os

/// Unified log. Watch it live with:
///   log stream --predicate 'subsystem == "app.orbitile.Orbitile"' --level debug
enum Log {
    static let app = Logger(subsystem: "app.orbitile.Orbitile", category: "app")
}
