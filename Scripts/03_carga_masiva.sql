USE gestion_usuarios_final;

SET @N := 100000; -- volumen de usuarios a generar


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
