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