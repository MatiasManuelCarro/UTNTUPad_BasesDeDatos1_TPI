DROP DATABASE IF EXISTS gestion_usuarios_final;

CREATE DATABASE IF NOT EXISTS gestion_usuarios_final

CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

USE gestion_usuarios_final;

SET @N := 100000; -- volumen de usuarios a generar

DROP TABLE IF EXISTS credencial_acceso;
DROP TABLE IF EXISTS usuario;

/* ===========================================================
CREACION DE TABLAS
=========================================================== */

CREATE TABLE usuario (
id_usuario INT NOT NULL AUTO_INCREMENT,
eliminado BOOLEAN NOT NULL DEFAULT FALSE,
username VARCHAR(60) NOT NULL,
nombre VARCHAR(100) NOT NULL,
apellido VARCHAR(100) NOT NULL,
email VARCHAR(120) NOT NULL,
fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
activo BOOLEAN NOT NULL DEFAULT TRUE,
estado VARCHAR(15) NOT NULL DEFAULT 'ACTIVO', -- NUEVO
CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
CONSTRAINT uq_usuario_username UNIQUE (username),
CONSTRAINT uq_usuario_email UNIQUE (email),
CONSTRAINT ck_usuario_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE credencial_acceso (
id_credencial INT NOT NULL AUTO_INCREMENT,
eliminado BOOLEAN NOT NULL DEFAULT FALSE,
usuario_id INT NOT NULL,
estado VARCHAR(15) NOT NULL,
ultima_sesion TIMESTAMP NULL,
hash_password VARCHAR(255) NOT NULL,
salt VARCHAR(64) NULL,
ultimo_cambio DATETIME NULL,
requiere_reset BOOLEAN NOT NULL DEFAULT FALSE,
CONSTRAINT pk_credencial PRIMARY KEY (id_credencial),
CONSTRAINT uq_credencial_usuario UNIQUE (usuario_id),
CONSTRAINT fk_credencial_usuario FOREIGN KEY (usuario_id)
REFERENCES usuario(id_usuario)
ON DELETE CASCADE ON UPDATE CASCADE,
CONSTRAINT ck_cred_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP INDEX ix_usuario_activo ON usuario;
DROP INDEX ix_usuario_estado ON usuario;
DROP INDEX ix_cred_estado ON credencial_acceso;


CREATE INDEX ix_usuario_activo ON usuario(activo);
CREATE INDEX ix_usuario_estado ON usuario(estado);
CREATE INDEX ix_cred_estado ON credencial_acceso(estado);

-- catalogo

CREATE TABLE estado (
    id_estado INT NOT NULL AUTO_INCREMENT,
    nombre_estado VARCHAR(20) NOT NULL,
    CONSTRAINT pk_estado PRIMARY KEY (id_estado),
    CONSTRAINT uq_estado UNIQUE (nombre_estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Carga inicial de valores del catálogo
INSERT INTO estado (nombre_estado)
VALUES ('ACTIVO'), ('INACTIVO');


DELIMITER $$
-- 1) Si el usuario está INACTIVO, su credencial no puede quedar ACTIVA.
CREATE TRIGGER bi_credencial_no_activa_si_usuario_inactivo
BEFORE INSERT ON credencial_acceso
FOR EACH ROW
BEGIN
DECLARE v_estado_usuario VARCHAR(15);
SELECT estado INTO v_estado_usuario
FROM usuario
WHERE id_usuario = NEW.usuario_id;
IF v_estado_usuario = 'INACTIVO' AND NEW.estado = 'ACTIVO' THEN
-- Forzamos a INACTIVO para mantener coherencia
SET NEW.estado = 'INACTIVO';
END IF;
END$$
CREATE TRIGGER bu_credencial_no_activa_si_usuario_inactivo
BEFORE UPDATE ON credencial_acceso
FOR EACH ROW
BEGIN
DECLARE v_estado_usuario VARCHAR(15);
SELECT estado INTO v_estado_usuario
FROM usuario
WHERE id_usuario = NEW.usuario_id;
IF v_estado_usuario = 'INACTIVO' AND NEW.estado = 'ACTIVO' THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'No se puede activar la credencial de un usuario
INACTIVO.';
END IF;
END$$

-- 2) Si cambia el estado del usuario, sincronizamos la credencial.
CREATE TRIGGER au_usuario_sync_estado_credencial
AFTER UPDATE ON usuario
FOR EACH ROW
BEGIN
IF NEW.estado <> OLD.estado THEN
UPDATE credencial_acceso
SET estado = CASE
WHEN NEW.estado = 'INACTIVO' THEN 'INACTIVO'
ELSE estado -- si el usuario pasa a ACTIVO, no forzamos; respetamos la cred actual
END
WHERE usuario_id = NEW.id_usuario;
END IF;
END$$
DELIMITER ;

/* ===========================================================
1) INSERCIÓN MASIVA USUARIOS
=========================================================== */
INSERT INTO usuario (username, eliminado, nombre, apellido, email,
fecha_registro, activo, estado)
SELECT
CONCAT(LOWER(nombre_sel.nombre), '.', LOWER(apellido_sel.apellido), '.',
nums.n) AS username,
FALSE,
nombre_sel.nombre,
apellido_sel.apellido,
CONCAT(LOWER(nombre_sel.nombre), '.', LOWER(apellido_sel.apellido), '.',
nums.n, '@example.com') AS email,
DATE_SUB(NOW(), INTERVAL (nums.n % 730) DAY),
CASE WHEN nums.n % 5 = 0 THEN FALSE ELSE TRUE END AS activo,
CASE WHEN nums.n % 7 = 0 THEN 'INACTIVO' ELSE 'ACTIVO' END AS estado -- patrón de ejemplo para poblar
FROM (
SELECT (d1.d*10000 + d2.d*1000 + d3.d*100 + d4.d*10 + d5.d) + 1 AS n
FROM
(SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
UNION ALL SELECT 4
UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL
SELECT 8 UNION ALL SELECT 9) d1
CROSS JOIN
(SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
UNION ALL SELECT 4
UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL
SELECT 8 UNION ALL SELECT 9) d2
CROSS JOIN
(SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
UNION ALL SELECT 4
UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL
SELECT 8 UNION ALL SELECT 9) d3
CROSS JOIN
(SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
UNION ALL SELECT 4
UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL
SELECT 8 UNION ALL SELECT 9) d4
CROSS JOIN
(SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
UNION ALL SELECT 4
UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL
SELECT 8 UNION ALL SELECT 9) d5
WHERE (d1.d*10000 + d2.d*1000 + d3.d*100 + d4.d*10 + d5.d) + 1 <= @N
) AS nums
JOIN (
SELECT 1 id,'Ana' nombre UNION ALL SELECT 2,'Juan' UNION ALL SELECT 3,'Sol'
UNION ALL SELECT 4,'Luis' UNION ALL
SELECT 5,'Lucía' UNION ALL SELECT 6,'Marcos' UNION ALL SELECT 7,'Elena'
UNION ALL SELECT 8,'Diego' UNION ALL
SELECT 9,'Carla' UNION ALL SELECT 10,'Sofía' UNION ALL SELECT 11,'Valentina'
UNION ALL SELECT 12,'Nicolás' UNION ALL
SELECT 13,'Martina' UNION ALL SELECT 14,'Agustín' UNION ALL SELECT
15,'Camila' UNION ALL SELECT 16,'Matías' UNION ALL
SELECT 17,'Florencia' UNION ALL SELECT 18,'Tomás' UNION ALL SELECT
19,'Paula' UNION ALL SELECT 20,'Gabriel'
) AS nombre_sel
ON nombre_sel.id = ((nums.n - 1) % 20) + 1
JOIN (
SELECT 1 id,'Gómez' apellido UNION ALL SELECT 2,'Pérez' UNION ALL SELECT
3,'Martínez' UNION ALL SELECT 4,'Ruiz' UNION ALL
SELECT 5,'López' UNION ALL SELECT 6,'Fernández' UNION ALL SELECT
7,'Sánchez' UNION ALL SELECT 8,'Vega' UNION ALL
SELECT 9,'Navarro' UNION ALL SELECT 10,'Castro' UNION ALL SELECT 11,'Silva'
UNION ALL SELECT 12,'Torres' UNION ALL
SELECT 13,'Romero' UNION ALL SELECT 14,'Molina' UNION ALL SELECT
15,'Ramos' UNION ALL SELECT 16,'Herrera' UNION ALL
SELECT 17,'Domínguez' UNION ALL SELECT 18,'Gutiérrez' UNION ALL SELECT
19,'Cabrera' UNION ALL SELECT 20,'Acosta'
) AS apellido_sel
ON apellido_sel.id = ((nums.n - 1) % 20) + 1
LEFT JOIN usuario u
ON u.username = CONCAT(LOWER(nombre_sel.nombre), '.',
LOWER(apellido_sel.apellido), '.', nums.n)
WHERE u.id_usuario IS NULL;

/* ===========================================================
2) CREDENCIALES 1:1 (coherentes con usuario.estado)
=========================================================== */
INSERT INTO credencial_acceso
(usuario_id, estado, ultima_sesion, eliminado, hash_password, salt,
ultimo_cambio, requiere_reset)
SELECT
u.id_usuario,
-- Si el usuario está INACTIVO, la credencial queda INACTIVA; si no, patrón de estados
CASE
WHEN u.estado = 'INACTIVO' THEN 'INACTIVO'
WHEN u.id_usuario % 5 = 0 THEN 'INACTIVO'
ELSE 'ACTIVO'
END AS estado,
TIMESTAMP(
DATE_SUB(CURDATE(), INTERVAL (u.id_usuario % 365) DAY),
SEC_TO_TIME((u.id_usuario % 86400))
),
FALSE,
UPPER(SHA2(CONCAT('pw:', u.id_usuario), 256)),
SUBSTRING(UPPER(SHA2(CONCAT('salt:', u.id_usuario), 256)), 1, 32),
DATE_SUB(NOW(), INTERVAL (u.id_usuario % 180) DAY),
(u.id_usuario % 20 = 0)
FROM usuario u
LEFT JOIN credencial_acceso c ON c.usuario_id = u.id_usuario
WHERE c.usuario_id IS NULL;

SELECT COUNT(*) AS total_filas
FROM usuario;

SELECT * from credencial_acceso;

/* ============================
Pruebas de consistencia: 
============================
*/

-- Conteos basicos

-- Total de usuarios
SELECT COUNT(*) FROM usuario;

-- Total de credenciales
SELECT COUNT(*) FROM credencial_acceso;

-- FK Huerfanas
SELECT c.id_credencial, c.usuario_id
FROM credencial_acceso c
LEFT JOIN usuario u ON c.usuario_id = u.id_usuario
WHERE u.id_usuario IS NULL;

-- Cardinalidades del dominio

-- Estados en usuario
SELECT DISTINCT estado FROM usuario;

-- Estados en credencial_acceso
SELECT DISTINCT estado FROM credencial_acceso;

-- Valores de activo
SELECT DISTINCT activo FROM usuario;

-- Se verifica que no se hayan creado usuarios sin nombre o apellido ingresado 

SELECT COUNT(*) AS usuarios_sin_nombre_o_apellido
FROM usuario
WHERE (nombre IS NULL OR nombre = '')
   OR (apellido IS NULL OR apellido = '');
   
   
/*
==================================================================
Etapa 3. Consultas complejas y útiles a partir del CRUD inicial
=================================================================
*/

-- consultas con JOIN

-- 1
select u.nombre, u.apellido, c.ultimo_cambio from usuario u join 
credencial_acceso c on u.id_usuario=c.usuario_id order by ultimo_cambio desc limit 10;


-- 2 
select u.nombre, u.apellido, c.ultima_sesion from usuario u join 
credencial_acceso c on u.id_usuario=c.usuario_id 
where c.ultima_sesion between "2025-05-15 04:24:00" and "2025-05-15 06:25:00";


show index from credencial_acceso;


-- =================================================
-- Consultas con índice y sin índice (repetir por 3)
-- =================================================

-- 1 Consulta repetida que utiliza join

select u.nombre, u.apellido, c.ultima_sesion from usuario u join 
credencial_acceso c on u.id_usuario=c.usuario_id 
where c.ultima_sesion between "2025-05-15 04:24:00" and "2025-05-15 06:25:00";

EXPLAIN select u.nombre, u.apellido, c.ultima_sesion from usuario u join 
credencial_acceso c on u.id_usuario=c.usuario_id 
where c.ultima_sesion between "2025-05-15 04:24:00" and "2025-05-15 06:25:00";

EXPLAIN ANALYZE select u.nombre, u.apellido, c.ultima_sesion from usuario u join 
credencial_acceso c on u.id_usuario=c.usuario_id 
where c.ultima_sesion between "2025-05-15 04:24:00" and "2025-05-15 06:25:00";

create index idx_ultima_sesion on credencial_acceso(ultima_sesion);
show index from credencial_acceso;

-- CODIGO PARA BORRAR EL INDICE (PARA PRUEBAS SOLAMENTE)
-- DROP INDEX idx_ultima_sesion ON credencial_acceso;

-- 2. Consulta con subconsulta. Asistencia de IA ChatGPT. Consulta repetida con cláusula where

--  Usuarios que requieren reset de contraseña. (esta consulta me dio tiempos de 0 segundos sin índice)

Explain SELECT 
    u.username,
    u.email,
    c.requiere_reset,
    c.ultimo_cambio
FROM usuario u
JOIN credencial_acceso c ON u.id_usuario = c.usuario_id
WHERE id_usuario in (select id_usuario from credencial_acceso where requiere_reset=1);


-- 3. Consulta con group by + having (utiliza between)

select count(*), estado from credencial_acceso where ultima_sesion between '2025-05-20 00:00:00' and '2025-05-20 23:59:59'
GROUP BY estado having count(estado) > 273 ;

explain select count(*), estado from credencial_acceso where ultima_sesion between '2025-05-20 00:00:00' and '2025-05-20 23:59:59'
GROUP BY estado having count(estado) > 273 ;

-- create index idx_ultima_sesion on credencial_acceso(ultima_sesion);
-- (Indice ya creado en etapas anteriores utilizar solo si se borro para realizar pruebas)
show index from credencial_acceso;


-- Consulta con vista

create view vista_usuarios_requiere_reset as
select u.id_usuario, u.nombre, u.apellido, u.email, c.requiere_reset 
from usuario u join credencial_acceso c on u.id_usuario=c.usuario_id ;

select id_usuario, requiere_reset from vista_usuarios_requiere_reset where id_usuario = 2;

/*
=======================================
Etapa 4 – Seguridad e Integridad
=======================================
*/

-- Creacion de las vistas para poder otorgar los permisos al usuario

-- vistas que ocultan informacion sensible

-- VISTA 1: v_usuarios_publico
-- Oculta: 'eliminado', 'fecha_registro' (información de auditoría/administración).
CREATE OR REPLACE VIEW v_usuarios_publico AS
SELECT
	id_usuario,
	username,
	nombre,
	apellido,
	email,
	activo
FROM
	usuario;

select * from v_usuarios_publico;

-- VISTA 2: v_credenciales_no_sensible
-- Oculta: 'hash_password' y 'salt' (información criptográfica sensible para autenticación).
CREATE OR REPLACE VIEW v_credenciales_no_sensible AS
SELECT
	usuario_id,
	estado,
	ultima_sesion,
	ultimo_cambio,
	requiere_reset
FROM
	credencial_acceso;

select * from v_credenciales_no_sensible;


-- creacion de usuarios y permisos

USE gestion_usuarios_final;
 
-- 1. CREACIÓN DEL USUARIO CON MÍNIMOS PRIVILEGIOS
-- Se crea un usuario de aplicación que solo puede conectarse desde la máquina local.
-- Se agrega el if not exists para evitar problemas durante la realizacion de multiples testeos del script. 
CREATE USER IF NOT EXISTS 'usuario_app'@'localhost' IDENTIFIED BY 'password_segura';
GRANT SELECT ON gestion_usuarios_final.* TO 'usuario_app'@'localhost';
GRANT SELECT ON gestion_usuarios_final.v_credenciales_no_sensible TO 'usuario_app'@'localhost';
FLUSH PRIVILEGES;


-- Pruebas de integridad

-- Prueba 1

-- se inserta un usuario de prueba 
INSERT INTO usuario (username, nombre, apellido, email) VALUES ('usuario_duplicado', 'Juan', 'Perez', 'dup1@test.com');

-- intento de violacion de la regla
-- (SE DEJA COMENTADO PARA EVITAR ERRORES DURANTE EL USO DEL SCRIPT COMPLETO)
-- INSERT INTO usuario (username, nombre, apellido, email) VALUES ('usuario_duplicado', 'Pedro', 'Gomez', 'dup2@test.com');

-- Prueba 2
-- Este codigo genera un error. Se deja comentado para poder ser utilizado SOLO PARA PRUEBAS
-- INSERT INTO credencial_acceso (usuario_id, estado, hash_password, salt) VALUES (999999, 'ACTIVO', 'hash_falso', 'salt_falso'); 

--  Procedimiento SQL seguro

 DELIMITER //
 
CREATE PROCEDURE sp_actualizar_password_seguro (
	IN p_usuario_id INT,
	IN p_nuevo_hash VARCHAR(255),
	IN p_nuevo_salt VARCHAR(64)
)
BEGIN
	-- Utiliza parámetros de entrada que son tratados como datos.
	-- La consulta está predefinida y no se construye con concatenación de strings (NO ES SQL DINÁMICO).
	UPDATE credencial_acceso
	SET
    	hash_password = p_nuevo_hash,
    	salt = p_nuevo_salt,
        ultimo_cambio = NOW(),
    	requiere_reset = FALSE
	WHERE
    	usuario_id = p_usuario_id;
    	
END //
 
DELIMITER ;
-- Limpiamos el delimitador

 
 -- Ejemplo de uso (Ejecución segura):
CALL sp_actualizar_password_seguro(1, 'nuevo_hash_cifrado_256', 'nuevo_salt_32_chars');

select * from credencial_acceso where id_credencial = 1;

-- Prueba anti-inyección

-- intento de intyeccion maliciosa, quiere borrar la tabla de credencial de acceso 
CALL sp_actualizar_password_seguro(
    1,
    'hash_falso''; DROP TABLE credencial_acceso; --',
    'salt_malicioso'
);

-- verificamos la tabla 
SELECT hash_password, salt
FROM credencial_acceso
WHERE usuario_id = 1;

SELECT * FROM credencial_acceso;

/*
=======================================
Etapa 5 – Concurrencia y Transacciones
=======================================
*/

-- Tabla para registrar los errores, incluyendo deadlocks
CREATE TABLE log_errores (
    id_log INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    procedimiento VARCHAR(100) NOT NULL,
    nivel VARCHAR(10) NOT NULL, -- 'ERROR', 'WARN', 'INFO'
    codigo_sql INT NULL,
    estado_sql VARCHAR(5) NULL,
    mensaje_error TEXT NOT NULL,
    intentos INT NULL
) ENGINE=InnoDB;

-- Se extiene el tiempo para las pruebas de deadlocks 
SET GLOBAL net_read_timeout = 600;
SET GLOBAL net_write_timeout = 600;
SET GLOBAL wait_timeout = 600;
SET GLOBAL interactive_timeout = 600;

-- ====================================================
-- Inicia creacion  p_actualizar_estado_activo_usuario (Procedimiento almacenado)
-- ====================================================

DELIMITER $$
-- delimiter cambia el punto y coma ; por $$ para poder utilizar ; dentro de la funcio

DROP PROCEDURE IF EXISTS p_actualizar_estado_activo_usuario $$
CREATE PROCEDURE p_actualizar_estado_activo_usuario(
    IN p_id_usuario   INT,
    IN p_nuevo_activo BOOLEAN
    -- identifica la fila del usuario y el valor que vamos a cambiar
)
BEGIN
    -- control de reintentos y estado
    DECLARE v_max_intentos       INT     DEFAULT 2;
    DECLARE v_intento_actual     INT     DEFAULT 0;
    DECLARE v_exito              BOOLEAN DEFAULT FALSE;
    DECLARE v_deadlock_detectado BOOLEAN DEFAULT FALSE;
    -- crea las variables necesarias

    -- datos para logging
    DECLARE v_codigo_error  INT;
    DECLARE v_estado_sql    VARCHAR(5);
    DECLARE v_mensaje_error TEXT;

    -- handler para deadlock (SQLSTATE 40001) (es el error de deadlock)
    DECLARE CONTINUE HANDLER FOR SQLSTATE '40001'
    BEGIN
        SET v_deadlock_detectado = TRUE;
        ROLLBACK;
        SET v_codigo_error  = 1213;
        SET v_estado_sql    = '40001';
        SET v_mensaje_error = CONCAT(
            'Deadlock al cambiar activo. Intento ', v_intento_actual + 1
        );
        INSERT INTO log_errores (
            procedimiento, nivel, codigo_sql, estado_sql, mensaje_error, intentos
        ) VALUES (
            'p_actualizar_estado_activo_usuario',
            'WARN',
            v_codigo_error,
            v_estado_sql,
            v_mensaje_error,
            v_intento_actual + 1
        );
        SELECT SLEEP(0.1);
    END;
        -- en caso de encontrar un deadlock, hace un rollback, captura los detalles y los almacena en la tabla de errores

    -- bucle de retry
    WHILE v_intento_actual <= v_max_intentos 
      AND v_exito = FALSE
    DO
        SET v_intento_actual     = v_intento_actual + 1;
        SET v_deadlock_detectado = FALSE;

        START TRANSACTION;
            UPDATE usuario
            SET activo = p_nuevo_activo
            WHERE id_usuario = p_id_usuario;
			-- si no hubo deadlock, confirmamos y marcamos éxito
        IF v_deadlock_detectado = FALSE THEN
            COMMIT;
            SET v_exito = TRUE;
        END IF;
    END WHILE;
      -- este bucle reintenta la transaccion hasta que alcanza el maximo de v_max_intentos

      -- si tras todos los intentos no hubo éxito
    IF v_exito = FALSE THEN
        IF v_deadlock_detectado = TRUE THEN
			-- si no tuvo existo y ademas encontro un deadlock:
            -- guarda en log_errores el error
            INSERT INTO log_errores (
                procedimiento, nivel, codigo_sql, estado_sql, mensaje_error, intentos
            ) VALUES (
                'p_actualizar_estado_activo_usuario',
                'ERROR',
                1213,
                '40001',
                CONCAT(
                  'FALLO DEFINITIVO: No se pudo cambiar activo de usuario ',
                  p_id_usuario,
                  ' tras ',
                  v_intento_actual,
                  ' intentos'
                ),
                v_intento_actual
            );
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error permanente por deadlocks. Intente más tarde.',
                    MYSQL_ERRNO   = 50005;
        ELSE
			-- rollback de seguridad si quedara activa
            IF EXISTS (
                SELECT 1
                  FROM information_schema.innodb_trx
                 WHERE trx_mysql_thread_id = CONNECTION_ID()
            ) THEN
                ROLLBACK;
            END IF;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error inesperado al cambiar activo.',
                    MYSQL_ERRNO   = 50006;
        END IF;
    END IF;
END $$
-- cierra el cuerpo del procedimiento con (como si fuera end;)
DELIMITER ;
-- vuelve a cambiar el delimiter a ;

-- prueba
CALL p_actualizar_estado_activo_usuario( 1, TRUE );
SELECT *
  FROM usuario
 WHERE id_usuario = 1;

SELECT * 
  FROM log_errores
 WHERE procedimiento = 'p_actualizar_estado_activo_usuario'
 ORDER BY id_log DESC
 LIMIT 5;


-- A PARTIR DE ESTA PARTE DEL CODIGO ES NECESARIO UTILIZAR LA SEGUNDA SESION. NO CORRER SOLO DESDE ESTA SESION
-- ======= read commited vs repeteable read ====

USE gestion_usuarios_prueba;

-- Aseguramos un estado inicial conocido
-- 1. Preparación del entorno
-- se crea este nombre de prueba
UPDATE usuario
SET nombre = 'Probando READ COMMITED'
WHERE id_usuario = 1;
COMMIT;

-- 2. Escenario de no‐lectura repetible en READ COMMITTED
--  READ COMMITTED Sesión 1 paso 1
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
  SELECT nombre
    FROM usuario
   WHERE id_usuario = 1; 
-- Resultado: 'Probando READ COMMITED'

-- continuar en la sesion 2

--  READ COMMITTED sesion 1 paso 3
  SELECT nombre
    FROM usuario
   WHERE id_usuario = 1;
   -- Resultado: vamos a ver lo que se ingreso en la sesion 2.
ROLLBACK;


-- == 3. Escenario de lectura repetible en REPEATABLE READ
-- REPEATABLE READ paso 1 Restaurar estado inicial
UPDATE usuario
   SET nombre = 'Probando REPETEABLE READ'
 WHERE id_usuario = 1;
COMMIT;

-- REPEATABLE READ paso 2 Sesión 1
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
  SELECT nombre
    FROM usuario
   WHERE id_usuario = 1;
-- Resultado: 'Probando REPETEABLE READ'

-- REPEATABLE READ PASO final sesion 1
  SELECT nombre
    FROM usuario
   WHERE id_usuario = 1;
-- Resultado: 'Original'  porque REPEATABLE READ mantiene la snapshot de la primera lectura
ROLLBACK;
-- cierra la tansaccion y no guarda los cambios realizados 


/* =====================================
Creacion de un deadlock para prueba
=====================================
*/
-- DEADLOCK USUARIO ACTIVO paso 1 sesion 1:
START TRANSACTION;
UPDATE usuario
   SET activo = FALSE
 WHERE id_usuario = 1;
-- Bloquea la fila con id_usuario = 1

-- DEADLOCK USUARIO ACTIVO paso 3 sesion 1
UPDATE usuario
   SET activo = TRUE
 WHERE id_usuario = 2;
-- Queda esperando porque Sesión 2 ya tiene lock sobre id_usuario = 2


-- ==============================================
-- == solucionando deadlock utilizando FOR UPDATE
-- ==============================================

-- EJECUTAR DE LA SESION 1
START TRANSACTION;
SELECT * FROM usuario WHERE id_usuario IN (1,2) FOR UPDATE;

UPDATE usuario
   SET activo = FALSE
 WHERE id_usuario = 1;

UPDATE usuario
   SET activo = FALSE
 WHERE id_usuario = 2;
COMMIT;

select * from usuario
where id_usuario IN (1, 2);


-- ===========================================
-- Impacto de índices en entornos concurrentes
-- ===========================================
SHOW INDEXES FROM usuario;

EXPLAIN ANALYZE
SELECT * 
FROM usuario
WHERE apellido = 'castro';

-- buscamos desde sesion 1

START TRANSACTION;
SELECT * FROM usuario WHERE apellido = 'Castro' FOR UPDATE;
-- no aplica commit, iniciar el mismo en la conexion 2
COMMIT;

-- Se crea un indice para realizar la prueba
CREATE INDEX ix_usuario_apellido ON usuario (apellido);

/*=============================
FINAL DEL SCRIPT
==============================
*/



