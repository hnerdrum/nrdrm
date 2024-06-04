package controllers

import (
	"net/http"
	"nrdrm/uno/database"
	"nrdrm/uno/models"
	"strconv"

	"github.com/gin-gonic/gin"
)

func getDB(c *gin.Context) database.DBClient {
	return c.MustGet("db").(database.DBClient)
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

type CreateGameInput struct {
	Title     string    `json:"title" binding:"required"`
  PlayerIDs []uint    `json:"player_ids" binding:"required"`
}

func CreateGame(c *gin.Context) {
	var input CreateGameInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	db := getDB(c)

	game, err := models.CreateGame(db, input.Title, input.PlayerIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, game)
}

func GetAllGames(c *gin.Context) {
	db := getDB(c)
	games, err := models.GetAllGames(db)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, games)
}

func GetGameById(c *gin.Context) {
	idParam := c.Param("id")
  id, err := strconv.Atoi(idParam)
   if err != nil {
       c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid player ID"})
       return
  }

	game, err := models.GetGameById(getDB(c), uint(id))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, game)
}