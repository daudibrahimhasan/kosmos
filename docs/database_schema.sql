-- V1 DATABASE SCHEMA
-- Two separate data domains:
--   A. LOCAL DEVICE DATABASE: contains gallery-derived data.
--   B. REMOTE SERVER DATABASE: contains account/business data only.
--
-- NEVER synchronize local gallery tables to the server.

-- ============================================================
-- A. LOCAL DEVICE DATABASE (SQLite)
-- ============================================================

CREATE TABLE local_assets (
    local_asset_id TEXT PRIMARY KEY,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
    width INTEGER,
    height INTEGER,
    duration_ms INTEGER,
    file_size_bytes INTEGER,
    created_at_device INTEGER,
    modified_at_device INTEGER,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    is_screenshot INTEGER NOT NULL DEFAULT 0,
    last_seen_at INTEGER NOT NULL,
    analysis_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (analysis_status IN ('pending', 'partial', 'complete', 'failed', 'deleted')),
    feature_version TEXT,
    UNIQUE(local_asset_id)
);

CREATE TABLE local_asset_features (
    local_asset_id TEXT PRIMARY KEY,
    blur_score REAL,
    brightness_score REAL,
    quality_score REAL,
    perceptual_hash TEXT,
    semantic_embedding BLOB,
    semantic_model_version TEXT,
    category_scores_json TEXT,
    predicted_category TEXT,
    analyzed_at INTEGER NOT NULL,
    FOREIGN KEY (local_asset_id) REFERENCES local_assets(local_asset_id) ON DELETE CASCADE
);

CREATE INDEX idx_local_asset_features_phash
ON local_asset_features(perceptual_hash);

CREATE TABLE local_similarity_clusters (
    cluster_id TEXT NOT NULL,
    local_asset_id TEXT NOT NULL,
    cluster_type TEXT NOT NULL
        CHECK (cluster_type IN ('exact_duplicate', 'near_duplicate', 'similar', 'burst')),
    similarity_score REAL,
    representative_asset_id TEXT,
    algorithm_version TEXT NOT NULL,
    PRIMARY KEY (cluster_id, local_asset_id),
    FOREIGN KEY (local_asset_id) REFERENCES local_assets(local_asset_id) ON DELETE CASCADE
);

CREATE INDEX idx_similarity_asset
ON local_similarity_clusters(local_asset_id);

CREATE TABLE local_user_decisions (
    decision_id TEXT PRIMARY KEY,
    local_asset_id TEXT NOT NULL,
    decision TEXT NOT NULL CHECK (decision IN ('keep', 'delete', 'skip')),
    source TEXT NOT NULL
        CHECK (source IN ('swipe', 'batch_review', 'duplicate_review', 'manual')),
    created_at INTEGER NOT NULL,
    feature_version TEXT,
    personal_model_version TEXT,
    FOREIGN KEY (local_asset_id) REFERENCES local_assets(local_asset_id) ON DELETE CASCADE
);

CREATE INDEX idx_decisions_asset_time
ON local_user_decisions(local_asset_id, created_at);

CREATE TABLE local_personal_predictions (
    local_asset_id TEXT PRIMARY KEY,
    delete_probability REAL NOT NULL,
    confidence REAL NOT NULL,
    reason_codes_json TEXT,
    personal_model_version TEXT NOT NULL,
    predicted_at INTEGER NOT NULL,
    FOREIGN KEY (local_asset_id) REFERENCES local_assets(local_asset_id) ON DELETE CASCADE
);

CREATE TABLE local_model_state (
    model_key TEXT PRIMARY KEY,
    model_version TEXT NOT NULL,
    training_sample_count INTEGER NOT NULL DEFAULT 0,
    model_blob BLOB,
    updated_at INTEGER NOT NULL
);

CREATE TABLE local_cleanup_batches (
    batch_id TEXT PRIMARY KEY,
    status TEXT NOT NULL
        CHECK (status IN ('draft', 'reviewing', 'approved', 'executing', 'completed', 'partial_failed', 'cancelled')),
    candidate_count INTEGER NOT NULL DEFAULT 0,
    estimated_bytes INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE local_cleanup_batch_items (
    batch_id TEXT NOT NULL,
    local_asset_id TEXT NOT NULL,
    selected INTEGER NOT NULL DEFAULT 1,
    suggestion_type TEXT NOT NULL,
    confidence REAL,
    estimated_bytes INTEGER,
    reason_codes_json TEXT,
    deletion_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (deletion_status IN ('pending', 'success', 'failed', 'skipped')),
    PRIMARY KEY (batch_id, local_asset_id),
    FOREIGN KEY (batch_id) REFERENCES local_cleanup_batches(batch_id) ON DELETE CASCADE,
    FOREIGN KEY (local_asset_id) REFERENCES local_assets(local_asset_id) ON DELETE CASCADE
);

CREATE TABLE local_cleanup_audit (
    audit_id TEXT PRIMARY KEY,
    batch_id TEXT,
    requested_count INTEGER NOT NULL,
    deleted_count INTEGER NOT NULL,
    failed_count INTEGER NOT NULL,
    bytes_reclaimed INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (batch_id) REFERENCES local_cleanup_batches(batch_id)
);

CREATE TABLE local_profile_stats (
    stat_key TEXT PRIMARY KEY,
    stat_value REAL NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE local_scan_state (
    scan_id TEXT PRIMARY KEY,
    scan_type TEXT NOT NULL,
    status TEXT NOT NULL
        CHECK (status IN ('queued', 'running', 'paused', 'completed', 'failed', 'cancelled')),
    processed_count INTEGER NOT NULL DEFAULT 0,
    total_count INTEGER,
    cursor_state_json TEXT,
    started_at INTEGER,
    updated_at INTEGER NOT NULL,
    completed_at INTEGER
);

-- ============================================================
-- B. REMOTE SERVER DATABASE (PostgreSQL)
-- NO GALLERY CONTENT
-- ============================================================

CREATE TABLE app_users (
    id UUID PRIMARY KEY,
    email TEXT,
    auth_provider TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ,
    account_status TEXT NOT NULL DEFAULT 'active'
        CHECK (account_status IN ('active', 'disabled', 'deleted'))
);

CREATE TABLE user_devices (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    install_id TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    os_version TEXT,
    app_version TEXT,
    device_class TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, install_id)
);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_customer_id TEXT,
    entitlement TEXT NOT NULL,
    status TEXT NOT NULL,
    product_id TEXT,
    current_period_end TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, entitlement)
);

CREATE TABLE feature_flags (
    key TEXT PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    config_json JSONB,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_feature_overrides (
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    flag_key TEXT NOT NULL REFERENCES feature_flags(key) ON DELETE CASCADE,
    enabled BOOLEAN,
    config_json JSONB,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, flag_key)
);

CREATE TABLE usage_daily (
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    sessions INTEGER NOT NULL DEFAULT 0,
    items_scanned INTEGER NOT NULL DEFAULT 0,
    items_reviewed INTEGER NOT NULL DEFAULT 0,
    items_deleted INTEGER NOT NULL DEFAULT 0,
    storage_saved_mb BIGINT NOT NULL DEFAULT 0,
    swipe_sessions INTEGER NOT NULL DEFAULT 0,
    smart_batches_reviewed INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, usage_date)
);

CREATE TABLE telemetry_events (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
    install_id TEXT,
    event_name TEXT NOT NULL,
    event_version INTEGER NOT NULL DEFAULT 1,
    aggregate_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_telemetry_event_name_time
ON telemetry_events(event_name, created_at);

CREATE TABLE app_config_versions (
    id UUID PRIMARY KEY,
    config_version TEXT NOT NULL UNIQUE,
    config_json JSONB NOT NULL,
    active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Server-side privacy constraint:
-- telemetry_events.aggregate_payload MUST be validated against an allowlist
-- before insertion. Never accept arbitrary client JSON.
