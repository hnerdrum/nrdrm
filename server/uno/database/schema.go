package database

import (
	"time"
)

type Game struct {
	ID        uint       `gorm:"primaryKey" json:"id"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	Title     string     `json:"title"`
	StartTime time.Time  `json:"start_time"`
	EndTime   *time.Time `json:"end_time,omitempty"`
	WinnerID  *uint      `json:"winner_id,omitempty"`
	Winner    *Player    `json:"winner" gorm:"foreignKey:WinnerID;references:ID"`
	Players   []*Player  `gorm:"many2many:game_players;" json:"players"`
	Rounds    []Round    `json:"rounds"`
}

type Round struct {
	ID        uint         `gorm:"primaryKey" json:"id"`
	CreatedAt time.Time    `json:"created_at"`
	UpdatedAt time.Time    `json:"updated_at"`
	GameID    uint         `json:"game_id"`
	Sequence  int          `json:"sequence"`
	WinnerID  *uint        `json:"winner_id,omitempty"`
  Winner    *Player      `json:"winner" gorm:"foreignKey:WinnerID;references:ID"`
	Scores    []RoundScore `json:"scores"`
}

type RoundScore struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	CreatedAt time.Time `json:"created_at"`
  UpdatedAt time.Time `json:"updated_at"`
  RoundID   uint      `json:"round_id"`
  Round     Round     `json:"round" gorm:"foreignKey:RoundID;references:ID"`
  PlayerID  uint      `json:"player_id"`
  Player    Player    `json:"player" gorm:"foreignKey:PlayerID;references:ID"`
  Score     int       `json:"score"`
  Rank      int       `json:"rank"`
}

type Player struct {
	ID   uint `gorm:"primaryKey" json:"id"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	Name      string `json:"name"`
	Games     []*Game    `gorm:"many2many:game_players;" json:"games"`
}