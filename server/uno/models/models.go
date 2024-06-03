package models

import (
	"nrdrm/uno/database"

	"gorm.io/gorm"
)

type Player struct {
	ID   uint `json:"id"`
	Name string `json:"name"`
}

func GetAllPlayers(db *gorm.DB) ([]Player, error) {
	var players []Player
  result := db.Find(&players)
  return players, result.Error
}

func CreatePlayer(db *gorm.DB, name string) (Player, error) {
	player := database.Player { Name: name }
	result := db.Create(&player)
	return fromDbPlayer(player), result.Error
}

func fromDbPlayer(player database.Player) Player {
	return Player { ID: player.ID, Name: player.Name }
}