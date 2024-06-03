package database

import (
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func Connect(url string) *gorm.DB {
	db, err := gorm.Open(postgres.Open(url))
	if err != nil {
			log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("Database connection established")
	log.Println("Running database migrations...")

	db.AutoMigrate(&Player{}, &Game{}, &Round{}, &RoundScore{})

	return db
}