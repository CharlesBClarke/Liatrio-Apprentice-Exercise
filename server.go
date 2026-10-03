package main

import (
	"log"
	"time"

	"github.com/gofiber/fiber/v3"
)

func main() {
	app := fiber.New()

	app.Get("/", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"message":   "My name is Charles Clarke",
			"timestamp": time.Now().Unix(),
		})
	})

	log.Fatal(app.Listen(":80"))
}
