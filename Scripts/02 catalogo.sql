USE gestion_usuarios_final;

CREATE TABLE estado (
    id_estado INT NOT NULL AUTO_INCREMENT,
    nombre_estado VARCHAR(20) NOT NULL,
    CONSTRAINT pk_estado PRIMARY KEY (id_estado),
    CONSTRAINT uq_estado UNIQUE (nombre_estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Carga inicial de valores del catálogo
INSERT INTO estado (nombre_estado)
VALUES ('ACTIVO'), ('INACTIVO');