package models

import (
	"nrdrm/uno/database"
	"time"
)

type Game struct {
	ID        uint       `json:"id"`
	Title     string     `json:"title"`
	StartTime time.Time  `json:"start_time"`
	EndTime   *time.Time `json:"end_time,omitempty"`
	WinnerID  *uint      `json:"winner_id,omitempty"`
	Players   []Player   `json:"players"`
}

type Player struct {
	ID   uint    `json:"id"`
	Name string  `json:"name"`
}

func GetAllPlayers(db database.DBClient) ([]Player, error) {
	var dbPlayers []database.Player
  result := db.Find(&dbPlayers)

	players := []Player{}
	for _, player := range dbPlayers {
		players = append(players, fromDbPlayer(player))
	}

  return players, result.Error
}

func CreatePlayer(db database.DBClient, name string) (Player, error) {
	player := database.Player { Name: name }
	result := db.Create(&player)
	return fromDbPlayer(player), result.Error
}

func GetAllGames(db database.DBClient) ([]Game, error) {
	var dbGames []database.Game
	result := db.Preload("Players").Find(&dbGames)

	games := []Game{}
	for _, game := range dbGames {
		games = append(games, fromDbGame(game))
	}

	return games, result.Error
}

func GetGameById(db database.DBClient, id uint) (Game, error) {
	var dbGame database.Game
	result := db.Preload("Players").First(&dbGame, id)
	return fromDbGame(dbGame), result.Error
}

func CreateGame(db database.DBClient, title string, playerIds []uint) (Game, error) {
	dbPlayers, err := GetPlayersByID(db, playerIds)

	if err != nil {
		return Game{}, err
	}

	game := database.Game { Title: title, Players: dbPlayers, StartTime: time.Now() }
	result := db.Create(&game)
	return fromDbGame(game), result.Error
}

func GetPlayersByID(db database.DBClient, playerIds []uint) ([]database.Player, error) {
	var dbPlayers []database.Player
	result := db.Where("id IN ?", playerIds).Find(&dbPlayers)
	return dbPlayers, result.Error
}

func fromDbGame(game database.Game) Game {
	players := []Player{}
	for _, player := range game.Players {
		players = append(players, fromDbPlayer(player))
	}

	return Game {
		ID: game.ID,
		Title: game.Title,
		StartTime: game.StartTime,
		EndTime: game.EndTime,
		WinnerID: game.WinnerID,
		Players: players,
	}
}

func fromDbPlayer(player database.Player) Player {
	return Player { ID: player.ID, Name: player.Name }
}
