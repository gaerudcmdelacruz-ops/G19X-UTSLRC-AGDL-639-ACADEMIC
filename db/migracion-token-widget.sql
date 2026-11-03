-- Solo para una base que YA tienes (creada antes de este cambio). Córrelo una sola vez.
-- Una base nueva, creada con base-de-datos.sql, ya trae la columna.
USE omnidesk_db;
ALTER TABLE conversaciones ADD COLUMN token_publico CHAR(48) NULL UNIQUE;
