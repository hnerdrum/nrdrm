package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port int
}

func LoadConfig() Config {
	err := godotenv.Load(".env")
  if err != nil{
   log.Fatalf("Error loading .env file: %s", err)
  }

	port := ParseInt(LoadEnvVar("PORT"))

	return Config { Port: port }
}

func LoadEnvVar(name string) string {
	value := os.Getenv(name)
	if value == "" {
		log.Fatalf("%s environment variable not set", name)
	}
	return value
}

func ParseInt(value string) int {
	num, err := strconv.Atoi(value)
	if err != nil {
			log.Fatalf("Error converting value to int: %v", err)
	}
	return num
}