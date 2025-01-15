package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
)

// Data structure to match your JSON dataset
type EngineData struct {
	Brand  string `json:"brand"`
	Models []struct {
		Name    string   `json:"name"`
		Engines []string `json:"engines"`
	} `json:"models"`
}

var automobileData []EngineData

func main() {
	// Load data from JSON file
	if err := loadData("data.json"); err != nil {
		log.Fatalf("Error loading data: %v", err)
	}

	// Set up router and routes
	router := mux.NewRouter()
	router.HandleFunc("/brands", getBrands).Methods("GET")
	router.HandleFunc("/models", getModels).Methods("GET")
	router.HandleFunc("/engines", getEngines).Methods("GET")

	log.Println("Server is running on port 8081")
	log.Fatal(http.ListenAndServe(":8081", router))
}

func loadData(filename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	if err := json.NewDecoder(file).Decode(&automobileData); err != nil {
		return err
	}
	return nil
}

func getBrands(w http.ResponseWriter, r *http.Request) {
	var brands []string
	for _, data := range automobileData {
		brands = append(brands, data.Brand)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(brands)
}

func getModels(w http.ResponseWriter, r *http.Request) {
	brand := r.URL.Query().Get("brand")
	if brand == "" {
		http.Error(w, "Missing brand parameter", http.StatusBadRequest)
		return
	}

	var models []string
	for _, data := range automobileData {
		if data.Brand == brand {
			for _, model := range data.Models {
				models = append(models, model.Name)
			}
			break
		}
	}

	if len(models) == 0 {
		http.Error(w, "Brand not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(models)
}

func getEngines(w http.ResponseWriter, r *http.Request) {
	model := r.URL.Query().Get("model")
	if model == "" {
		http.Error(w, "Missing model parameter", http.StatusBadRequest)
		return
	}

	var engines []string
	for _, data := range automobileData {
		for _, m := range data.Models {
			if m.Name == model {
				engines = m.Engines
				break
			}
		}
	}

	if len(engines) == 0 {
		http.Error(w, "Model not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(engines)
}
