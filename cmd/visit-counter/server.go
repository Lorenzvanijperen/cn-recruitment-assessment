package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

const correlationHeader = "X-Correlation-ID"

type visitCounter struct {
	pool                  *pgxpool.Pool
	deploymentEnvironment string
}

func serve(
	ctx context.Context,
	databaseURL string,
	deploymentEnvironment string,
	address string,
	logger *slog.Logger,
) error {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return fmt.Errorf("configure database pool: %w", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		return fmt.Errorf("connect to database: %w", err)
	}

	counter := &visitCounter{
		pool:                  pool,
		deploymentEnvironment: deploymentEnvironment,
	}
	mux := http.NewServeMux()
	mux.Handle("POST /visits", counter.handler(logger))

	server := &http.Server{
		Addr:              address,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	serverErrors := make(chan error, 1)
	go func() {
		logger.Info("server started", "address", address, "deployment_environment", deploymentEnvironment)
		serverErrors <- server.ListenAndServe()
	}()

	select {
	case err := <-serverErrors:
		if err == http.ErrServerClosed {
			return nil
		}
		return fmt.Errorf("serve HTTP: %w", err)
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			return fmt.Errorf("shut down HTTP server: %w", err)
		}
		return nil
	}
}

func (counter *visitCounter) handler(logger *slog.Logger) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startedAt := time.Now()
		correlationID := r.Header.Get(correlationHeader)
		if correlationID == "" {
			var err error
			correlationID, err = newCorrelationID()
			if err != nil {
				logger.Error("request failed", "method", r.Method, "path", r.URL.Path, "error", err)
				writeError(w, http.StatusInternalServerError)
				return
			}
		}
		w.Header().Set(correlationHeader, correlationID)

		queryCtx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		count, err := counter.increment(queryCtx)
		if err != nil {
			logger.Error(
				"request failed",
				"method", r.Method,
				"path", r.URL.Path,
				"status", http.StatusInternalServerError,
				"correlation_id", correlationID,
				"deployment_environment", counter.deploymentEnvironment,
				"error", err,
			)
			writeError(w, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		response := `{"count":` + strconv.FormatInt(count, 10) + `}`
		if _, err := io.WriteString(w, response); err != nil {
			logger.Error(
				"response write failed",
				"method", r.Method,
				"path", r.URL.Path,
				"status", http.StatusOK,
				"correlation_id", correlationID,
				"deployment_environment", counter.deploymentEnvironment,
				"error", err,
			)
			return
		}

		logger.Info(
			"request completed",
			"method", r.Method,
			"path", r.URL.Path,
			"status", http.StatusOK,
			"correlation_id", correlationID,
			"deployment_environment", counter.deploymentEnvironment,
			"count", count,
			"duration_ms", time.Since(startedAt).Milliseconds(),
		)
	})
}

func (counter *visitCounter) increment(ctx context.Context) (int64, error) {
	const query = `
		INSERT INTO visit_counts AS current (deployment_environment, count)
		VALUES ($1, 1)
		ON CONFLICT (deployment_environment)
		DO UPDATE SET count = current.count + 1
		RETURNING count`

	var count int64
	if err := counter.pool.QueryRow(ctx, query, counter.deploymentEnvironment).Scan(&count); err != nil {
		return 0, fmt.Errorf("persist visit: %w", err)
	}
	return count, nil
}

func newCorrelationID() (string, error) {
	value := make([]byte, 16)
	if _, err := rand.Read(value); err != nil {
		return "", fmt.Errorf("generate correlation ID: %w", err)
	}
	return hex.EncodeToString(value), nil
}

func writeError(w http.ResponseWriter, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, `{"error":"failed to record visit"}`)
}
