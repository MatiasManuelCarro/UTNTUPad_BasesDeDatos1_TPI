USE gestion_usuarios_final;
-- =========================
-- sesion 2
-- =========================


-- ======= read commited vs repeteable read ====

--  READ COMMITTED sesion 2 paso 2 de READ commited
UPDATE usuario
   SET nombre = 'RC_Modificado'
 WHERE id_usuario = 1;
COMMIT;

-- Escenario de lectura repetible en REPEATABLE READ
--  REPEATABLE READ paso 3 Sesión 2
UPDATE usuario
   SET nombre = 'RR_Modificado'
 WHERE id_usuario = 1;
COMMIT;

 SELECT nombre
    FROM usuario
   WHERE id_usuario = 1;
   
   
-- =========== simulando deadlock con usuario activo =======
-- DEADLOCK USUARIO ACTIVO paso 2 sesion 2:

START TRANSACTION;
UPDATE usuario
   SET activo = FALSE
 WHERE id_usuario = 2;
-- loquea la fila con id_usuario = 2

-- DEADLOCK USUARIO ACTIVO  paso 4 sesion 2
UPDATE usuario
   SET activo = TRUE
 WHERE id_usuario = 1;
-- Aquí MySQL detecta el ciclo de espera y lanza un DEADLOCK


-- ==============================================
-- == solucionando deadlock utilizando FOR UPDATE
-- ==============================================

-- EJECTURAR DESPUES DE SESION 1, ESTA TRANSACCION TIENE QUE ESPERAR 
START TRANSACTION;
SELECT * FROM usuario WHERE id_usuario IN (1,2) FOR UPDATE;

UPDATE usuario
   SET activo = TRUE
 WHERE id_usuario = 1;

UPDATE usuario
   SET activo = TRUE
 WHERE id_usuario = 2;

COMMIT;

select * from usuario
where id_usuario IN (1, 2);


-- ==========================
-- impacto de indices 
-- =============================

START TRANSACTION;
SELECT * FROM usuario WHERE apellido = 'Silva' FOR UPDATE;
-- esperar no realizar commit
COMMIT;


