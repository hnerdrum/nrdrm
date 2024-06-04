package database

import (
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type DBClient = *gorm.DB

func Connect(url string) DBClient {
	db, err := gorm.Open(postgres.Open(url))
	if err != nil {
			log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("Database connection established")
	log.Println("Running database migrations...")

	db.AutoMigrate(&Player{}, &Game{}, &Round{}, &RoundScore{})

	return db
}