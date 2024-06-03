package main

import (
	"fmt"
	"nrdrm/uno/config"
	"nrdrm/uno/database"
	"nrdrm/uno/routes"

	"github.com/gin-gonic/gin"
)

func main() {
	config := config.LoadConfig()

	db := database.Connect(config.DatabaseUrl)

	router := gin.Default()
	router.Use(func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	})
	routes.RegisterRoutes(router)

	router.Run(fmt.Sprint(":", config.Port))
}