USE gestion_usuarios_final; 
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

 