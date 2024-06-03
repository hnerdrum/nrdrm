package routes

import (
	"nrdrm/uno/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine) {
	router.GET("/players", controllers.GetAllPlayers)
	router.POST("/players", controllers.CreatePlayer)
}