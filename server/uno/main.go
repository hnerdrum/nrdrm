package main

import (
	"fmt"
	"nrdrm/uno/config"
	"nrdrm/uno/routes"

	"github.com/gin-gonic/gin"
)

func main() {
  router := gin.Default()
	routes.RegisterRoutes(router)	

	config := config.LoadConfig()

	router.Run(fmt.Sprint(":", config.Port))
}