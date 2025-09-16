using BonitoBook
using Bonito

# Create some sample tasks with different statuses
task1 = BonitoBook.TaskData("Setup Database", "Create and configure the database schema for user management")
task1.status = BonitoBook.started
task1.current_message = "Setting up PostgreSQL database with user tables"
task1.modified_files = ["src/database.jl", "config/database.yml"]
task1.file_diffs["src/database.jl"] = (
    "# Empty file",
    """using LibPQ

    function connect_db()
        conn = LibPQ.Connection("postgresql://user:pass@localhost/mydb")
        return conn
    end

    function create_user_table(conn)
        execute(conn, \"\"\"
            CREATE TABLE users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        \"\"\")
    end"""
)

task2 = BonitoBook.TaskData("Implement Authentication", "Add JWT-based authentication system")
task2.status = BonitoBook.progress
task2.current_message = "Working on JWT token generation and validation"
task2.modified_files = ["src/auth.jl", "src/middleware.jl"]
task2.file_diffs["src/auth.jl"] = (
    "",
    """module AuthService

    using JWT
    using Dates

    function generate_token(user_id::String)
        payload = Dict("user_id" => user_id, "exp" => now() + Hour(24))
        return JWT.encode(payload, "secret-key")
    end

    end"""
)

task3 = BonitoBook.TaskData("Add User Registration", "Create user registration endpoints and validation")
task3.status = BonitoBook.queued
task3.current_message = ""

task4 = BonitoBook.TaskData("Setup Email Service", "Configure email sending for verification and notifications")
task4.status = BonitoBook.finished
task4.current_message = "Email service configuration completed"
task4.modified_files = ["src/email.jl", "config/email.yml"]

# Create the dashboard
dashboard = BonitoBook.AIDashboard([task1, task2, task3, task4])

# Start the app - you can run this to see the full dashboard
App() do
    dashboard
end