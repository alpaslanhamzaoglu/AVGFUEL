package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"

	firebase "firebase.google.com/go"
	"google.golang.org/api/option"
)

type Vehicle struct {
	Brand  string   `json:"brand"`
	Models []Model  `json:"models"`
}

type Model struct {
	Name    string   `json:"name"`
	Engines []string `json:"engines"`
}

func main() {
	// Initialize Firebase
	ctx := context.Background()
	conf := &firebase.Config{ProjectID: "avgfuel-aea25"}
	opt := option.WithCredentialsFile("./serviceAccountKey.json") // Make sure this file exists
	app, err := firebase.NewApp(ctx, conf, opt)
	if err != nil {
		log.Fatalf("Error initializing app: %v", err)
	}

	client, err := app.Firestore(ctx)
	if err != nil {
		log.Fatalf("Error initializing Firestore: %v", err)
	}
	defer client.Close()

	// Read JSON file
	fileData, err := ioutil.ReadFile("../backend/data.json")
	if err != nil {
		log.Fatalf("Error reading file: %v", err)
	}

	var vehicles []Vehicle
	err = json.Unmarshal(fileData, &vehicles)
	if err != nil {
		log.Fatalf("Error parsing JSON: %v", err)
	}

	// Batch write
	for _, vehicle := range vehicles {
		brandRef := client.Collection("vehicleBrands").Doc(vehicle.Brand) // Brand document

		for _, model := range vehicle.Models {
			modelRef := brandRef.Collection("models").Doc(model.Name) // Model subcollection

			for _, engine := range model.Engines {
				engineRef := modelRef.Collection("engines").NewDoc() // Engine subcollection
				_, err := engineRef.Set(ctx, map[string]interface{}{
					"name": engine,
				})
				if err != nil {
					log.Fatalf("Error adding engine: %v", err)
				}
			}

			// Add the model document with just a name field
			_, err := modelRef.Set(ctx, map[string]interface{}{
				"name": model.Name,
			})
			if err != nil {
				log.Fatalf("Error adding model: %v", err)
			}
		}

		// Add the brand document
		_, err := brandRef.Set(ctx, map[string]interface{}{
			"name": vehicle.Brand,
		})
		if err != nil {
			log.Fatalf("Error adding brand: %v", err)
		}
	}

	fmt.Println("Data upload complete!")
}
