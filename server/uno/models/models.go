package models

import (
	"gorm.io/gorm"
)

func GetAllPlayers(db *gorm.DB) ([]Player, error) {
	var players []Player
  result := db.Find(&players)
  return players, result.Error
}

func CreatePlayer(db *gorm.DB, name string) (Player, error) {
	player := Player { Name: name }
	result := db.Create(&player)
	return player, result.Error
}