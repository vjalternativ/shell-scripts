#!/bin/bash

# Project name
PROJECT_NAME="mysql_app"

# Function to create a directory structure
create_dir_structure() {
  echo "Creating directory structure..."
  mkdir -p $PROJECT_NAME/{cmd/server,config,internal/{db,handlers,models,routes,services},pkg/utils}
}

# Function to create main.go
create_main() {
  echo "Creating cmd/server/main.go..."
  cat <<EOF > $PROJECT_NAME/cmd/server/main.go
package main

import (
	"log"
	"mysql_app/config"
	"mysql_app/internal/db"
	"mysql_app/internal/routes"

	"github.com/labstack/echo/v4"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize MySQL database connection
	err := db.Connect(db.Config{
		DatabaseDSN:     cfg.DatabaseDSN,
		MaxRetries:      cfg.MaxRetries,
		RetryDelay:      cfg.RetryDelay,
		MaxOpenConns:    cfg.MaxOpenConns,
		MaxIdleConns:    cfg.MaxIdleConns,
		ConnMaxLifetime: cfg.ConnMaxLifetime,
	})
	if err != nil {
		log.Fatalf("Failed to connect to the database: %v", err)
	}
	defer db.Close()

	// Initialize Echo
	e := echo.New()

	// Register routes
	routes.RegisterRoutes(e)

	// Start the server
	log.Println("Server running on port", cfg.ServerPort)
	log.Fatal(e.Start(":" + cfg.ServerPort))
}
EOF
}

# Function to create config.go
create_config() {
  echo "Creating config/config.go..."
  cat <<EOF > $PROJECT_NAME/config/config.go
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
    "github.com/joho/godotenv"
)

type Config struct {
	ServerPort      string
	DatabaseDSN     string
	MaxRetries      int
	RetryDelay      time.Duration
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

func Load() *Config {
    err := godotenv.Load()
	if err != nil {
		fmt.Println("Error loading .env file:", err)
	}
	maxRetries, _ := strconv.Atoi(getEnv("DB_MAX_RETRIES", "5"))
	retryDelay, _ := time.ParseDuration(getEnv("DB_RETRY_DELAY", "2s"))
	maxOpenConns, _ := strconv.Atoi(getEnv("DB_MAX_OPEN_CONNS", "25"))
	maxIdleConns, _ := strconv.Atoi(getEnv("DB_MAX_IDLE_CONNS", "5"))
	connMaxLifetime, _ := time.ParseDuration(getEnv("DB_CONN_MAX_LIFETIME", "30m"))

	return &Config{
		ServerPort:      getEnv("SERVER_PORT", "8080"),
		DatabaseDSN:     getEnv("DATABASE_DSN", "user:password@tcp(localhost:3306)/mysql_app"),
		MaxRetries:      maxRetries,
		RetryDelay:      retryDelay,
		MaxOpenConns:    maxOpenConns,
		MaxIdleConns:    maxIdleConns,
		ConnMaxLifetime: connMaxLifetime,
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
EOF
}

# Function to create db.go
create_db() {
  echo "Creating internal/db/db.go..."
  cat <<EOF > $PROJECT_NAME/internal/db/db.go
package db

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

var DB *sql.DB

type Config struct {
	DatabaseDSN     string
	MaxRetries      int
	RetryDelay      time.Duration
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

func Connect(cfg Config) error {
	var db *sql.DB
	var err error

	for i := 0; i <= cfg.MaxRetries; i++ {
		db, err = sql.Open("mysql", cfg.DatabaseDSN)
		if err == nil {
			err = db.Ping()
			if err == nil {
				db.SetMaxOpenConns(cfg.MaxOpenConns)
				db.SetMaxIdleConns(cfg.MaxIdleConns)
				db.SetConnMaxLifetime(cfg.ConnMaxLifetime)

				DB = db
				log.Println("MySQL database connected successfully")
				return nil
			}
		}

		log.Printf("Failed to connect to MySQL (attempt %d/%d): %v", i+1, cfg.MaxRetries, err)
		time.Sleep(cfg.RetryDelay)
	}

	return fmt.Errorf("could not connect to MySQL: %w", err)
}

func Close() {
	if DB != nil {
		err := DB.Close()
		if err != nil {
			log.Printf("Error closing MySQL connection: %v", err)
		} else {
			log.Println("MySQL connection closed")
		}
	}
}
EOF
}

# Function to create a placeholder handler
create_handler() {
  echo "Creating internal/handlers/user.go..."
  cat <<EOF > $PROJECT_NAME/internal/handlers/user.go
package handlers

import (
	"net/http"

	"github.com/labstack/echo/v4"
)

func GetUsers(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{"message": "List of users"})
}
EOF
}

# Function to create routes
create_routes() {
  echo "Creating internal/routes/routes.go..."
  cat <<EOF > $PROJECT_NAME/internal/routes/routes.go
package routes

import (
	"mysql_app/internal/handlers"

	"github.com/labstack/echo/v4"
)

func RegisterRoutes(e *echo.Echo) {
	api := e.Group("/api/v1")
	api.GET("/users", handlers.GetUsers)
}
EOF
}

# Function to create .env
create_env() {
  echo "Creating .env file..."
  cat <<EOF > $PROJECT_NAME/.env
SERVER_PORT=8080
DATABASE_DSN=user:password@tcp(localhost:3306)/mysql_app
DB_MAX_RETRIES=5
DB_RETRY_DELAY=2s
DB_MAX_OPEN_CONNS=25
DB_MAX_IDLE_CONNS=5
DB_CONN_MAX_LIFETIME=30m
EOF
}

# Function to initialize Go modules
init_go_mod() {
  echo "Initializing Go modules..."
  cd $PROJECT_NAME
  go mod init $PROJECT_NAME
  go get github.com/labstack/echo/v4 github.com/go-sql-driver/mysql
  cd ..
}

# Create the project
create_dir_structure
create_main
create_config
create_db
create_handler
create_routes
create_env
init_go_mod

echo "Quick start project created successfully in $PROJECT_NAME!"
