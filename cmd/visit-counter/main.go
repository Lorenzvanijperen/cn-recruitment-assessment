package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := run(ctx, os.Args[1:]); err != nil {
		slog.Error("command failed", "error", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string) error {
	if len(args) != 1 {
		return errors.New("usage: visit-counter <serve|migrate>")
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return errors.New("DATABASE_URL is required")
	}

	switch args[0] {
	case "migrate":
		return migrate(ctx, databaseURL)
	case "serve":
		deploymentEnvironment := os.Getenv("DEPLOYMENT_ENVIRONMENT")
		if deploymentEnvironment == "" {
			return errors.New("DEPLOYMENT_ENVIRONMENT is required")
		}

		port := os.Getenv("PORT")
		if port == "" {
			port = "8080"
		}

		return serve(ctx, databaseURL, deploymentEnvironment, net.JoinHostPort("", port), slog.Default())
	default:
		return fmt.Errorf("unknown command %q; expected serve or migrate", args[0])
	}
}
