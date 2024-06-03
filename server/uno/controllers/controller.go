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