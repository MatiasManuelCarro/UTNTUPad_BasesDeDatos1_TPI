USE gestion_usuarios_final;	

-- elimina los indices si existian anteriormente
DROP INDEX ix_usuario_activo ON usuario;
DROP INDEX ix_usuario_estado ON usuario;
DROP INDEX ix_cred_estado ON credencial_acceso;

-- se crean los indices para la tabla.
CREATE INDEX ix_usuario_activo ON usuario(activo);
CREATE INDEX ix_usuario_estado ON usuario(estado);
CREATE INDEX ix_cred_estado ON credencial_acceso(estado);