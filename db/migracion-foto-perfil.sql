-- Solo para una base que YA tienes (creada antes de la foto de perfil). Córrelo una sola vez.
-- Una base nueva, creada con base-de-datos.sql, ya trae la columna.
USE omnidesk_db;
ALTER TABLE usuarios ADD COLUMN foto VARCHAR(80) NULL AFTER telefono;
