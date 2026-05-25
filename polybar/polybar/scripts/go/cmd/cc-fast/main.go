package main

import (
	"encoding/json"
	"fmt"
	"os"

	"controlcenter/internal/metrics"
)

func main() {
	data := metrics.Collect()
	enc := json.NewEncoder(os.Stdout)
	if err := enc.Encode(data); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
