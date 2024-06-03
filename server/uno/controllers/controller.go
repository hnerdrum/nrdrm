package controllers

import (
	"net/http"
	"nrdrm/uno/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func getDB(c *gin.Context) *gorm.DB {
	return c.MustGet("db").(*gorm.DB)
}

func GetAllPlayers(c *gin.Context) {
	db := getDB(c)
	players, err := models.GetAllPlayers(db)
	if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
	}
	c.JSON(http.StatusOK, players)
}

type CreatePlayerInput struct {
	Name string `json:"name" binding:"required"`
}

func CreatePlayer(c *gin.Context) {
	var input CreatePlayerInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	db := getDB(c)

	player, err := models.CreatePlayer(db, input.Name)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, player)
}