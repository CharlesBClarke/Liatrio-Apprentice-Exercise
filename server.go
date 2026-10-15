package main

import (
	"log"
	"math/rand/v2"
	"time"

	"github.com/gofiber/fiber/v3"
)

var version = "dev"

func main() {
	app := fiber.New()

	app.Get("/", func(c fiber.Ctx) error {
		timestamp := time.Now().UnixMilli()
		return c.JSON(fiber.Map{
			"message":   "My name is Charles Clarke",
			"timestamp": timestamp,
			"version":   version,
			"divided":   timestamp / rand.Int64N(50),
		})
	})

	log.Fatal(app.Listen(":80"))
}
