package main

import (
	"fmt"
	"nrdrm/uno/config"
	"nrdrm/uno/database"
	"nrdrm/uno/routes"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func GetCorsConfig(config config.Config) cors.Config {
	return cors.Config {
    AllowOrigins: config.AllowedOrigins,
    AllowMethods: []string{"GET", "POST", "DELETE", "PUT", "PATCH", "OPTIONS"},
    AllowHeaders: []string{"Origin", "Content-Type"},
    AllowCredentials: true,
  }
}

func main() {
	config := config.LoadConfig()

	db := database.Connect(config.DatabaseUrl)

	router := gin.Default()
	router.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	router.Use(cors.New(GetCorsConfig(config)))
	routes.RegisterRoutes(router)

	router.Run(fmt.Sprint(":", config.Port))
}