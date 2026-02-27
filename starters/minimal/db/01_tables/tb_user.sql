CREATE TABLE IF NOT EXISTS tb_user (
    pk_user    INTEGER  PRIMARY KEY AUTOINCREMENT,
    id         TEXT     NOT NULL UNIQUE,
    name       TEXT     NOT NULL,
    email      TEXT     NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
