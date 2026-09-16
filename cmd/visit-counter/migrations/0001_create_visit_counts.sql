CREATE TABLE visit_counts (
    deployment_environment TEXT PRIMARY KEY,
    count BIGINT NOT NULL DEFAULT 0 CHECK (count >= 0)
);
