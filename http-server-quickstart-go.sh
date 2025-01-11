#!/bin/bash

# Project name
PROJECT_NAME="myapp"

# Create directory structure
echo "Creating project structure..."
mkdir -p ${PROJECT_NAME}/{cmd/server,config,internal/{routes,handlers,models,services,db},pkg/utils}

# Create go.mod file
echo "Initializing Go module..."
cd ${PROJECT_NAME} || exit
go mod init ${PROJECT_NAME}

# Create main.go
cat > cmd/server/main.go << 'EOF'
package main

import (
    "log"
    "myapp/config"
    "myapp/internal/routes"
    "github.com/labstack/echo/v4"
)

func main() {
    // Load config
    cfg := config.Load()

    // Initialize Echo
    e := echo.New()

    // Register routes
    routes.RegisterRoutes(e)

    // Start the server
    log.Println("Server running on port", cfg.ServerPort)
    log.Fatal(e.Start(":" + cfg.ServerPort))
}
EOF

# Create config/config.go
cat > config/config.go << 'EOF'
package config

import (
    "os"
)

type Config struct {
    ServerPort string
    DatabaseDSN string
}

func Load() *Config {
    return &Config{
        ServerPort: getEnv("SERVER_PORT", "8080"),
        DatabaseDSN: getEnv("DATABASE_DSN", "user:password@tcp(localhost:3306)/myapp"),
    }
}

func getEnv(key, fallback string) string {
    if value, exists := os.LookupEnv(key); exists {
        return value
    }
    return fallback
}
EOF

# Create internal/routes/routes.go
cat > internal/routes/routes.go << 'EOF'
package routes

import (
    "myapp/internal/handlers"
    "github.com/labstack/echo/v4"
)

func RegisterRoutes(e *echo.Echo) {
    // Grouping routes
    api := e.Group("/api/v1")

    // User routes
    api.GET("/users", handlers.GetUsers)
    api.GET("/users/:id", handlers.GetUserByID)
    api.POST("/users", handlers.CreateUser)
    api.PUT("/users/:id", handlers.UpdateUser)
    api.DELETE("/users/:id", handlers.DeleteUser)
}
EOF

# Create internal/handlers/user.go
cat > internal/handlers/user.go << 'EOF'
package handlers

import (
    "myapp/internal/models"
    "myapp/internal/services"
    "net/http"
    "github.com/labstack/echo/v4"
)

func GetUsers(c echo.Context) error {
    users := services.GetAllUsers()
    return c.JSON(http.StatusOK, users)
}

func GetUserByID(c echo.Context) error {
    id := c.Param("id")
    user, err := services.GetUserByID(id)
    if err != nil {
        return c.JSON(http.StatusNotFound, echo.Map{"error": "User not found"})
    }
    return c.JSON(http.StatusOK, user)
}

func CreateUser(c echo.Context) error {
    var user models.User
    if err := c.Bind(&user); err != nil {
        return c.JSON(http.StatusBadRequest, echo.Map{"error": "Invalid input"})
    }
    services.CreateUser(user)
    return c.JSON(http.StatusCreated, user)
}

func UpdateUser(c echo.Context) error {
    id := c.Param("id")
    var user models.User
    if err := c.Bind(&user); err != nil {
        return c.JSON(http.StatusBadRequest, echo.Map{"error": "Invalid input"})
    }
    if err := services.UpdateUser(id, user); err != nil {
        return c.JSON(http.StatusNotFound, echo.Map{"error": "User not found"})
    }
    return c.JSON(http.StatusOK, user)
}

func DeleteUser(c echo.Context) error {
    id := c.Param("id")
    if err := services.DeleteUser(id); err != nil {
        return c.JSON(http.StatusNotFound, echo.Map{"error": "User not found"})
    }
    return c.JSON(http.StatusNoContent, nil)
}
EOF

# Create internal/models/user.go
cat > internal/models/user.go << 'EOF'
package models

type User struct {
    ID    string `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}
EOF

# Create internal/services/user_service.go
cat > internal/services/user_service.go << 'EOF'
package services

import (
    "errors"
    "myapp/internal/models"
)

var users = []models.User{
    {ID: "1", Name: "John Doe", Email: "john@example.com"},
    {ID: "2", Name: "Jane Smith", Email: "jane@example.com"},
}

func GetAllUsers() []models.User {
    return users
}

func GetUserByID(id string) (models.User, error) {
    for _, user := range users {
        if user.ID == id {
            return user, nil
        }
    }
    return models.User{}, errors.New("user not found")
}

func CreateUser(user models.User) {
    users = append(users, user)
}

func UpdateUser(id string, updatedUser models.User) error {
    for i, user := range users {
        if user.ID == id {
            users[i] = updatedUser
            return nil
        }
    }
    return errors.New("user not found")
}

func DeleteUser(id string) error {
    for i, user := range users {
        if user.ID == id {
            users = append(users[:i], users[i+1:]...)
            return nil
        }
    }
    return errors.New("user not found")
}
EOF

# Create pkg/utils/response.go
cat > pkg/utils/response.go << 'EOF'
package utils

import "github.com/labstack/echo/v4"

func JSONError(c echo.Context, statusCode int, message string) error {
    return c.JSON(statusCode, echo.Map{"error": message})
}
EOF

# Success message
echo "Project ${PROJECT_NAME} has been created successfully!"
