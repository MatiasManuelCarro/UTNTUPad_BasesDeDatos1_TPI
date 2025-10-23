
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
