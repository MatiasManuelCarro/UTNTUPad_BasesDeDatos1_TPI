USE gestion_usuarios_final;   

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