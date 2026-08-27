-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que schema.sql ya se haya ejecutado antes.
--
-- Crea la fila de inscripciones para la cuenta admin
-- (comunidadhk901@gmail.com) para que pueda publicar, crear grupos y
-- conectar dentro de Comunidad HK a nombre de "HK Human Capital" en
-- vez de un perfil personal. Es una sola vez: si la fila ya existe,
-- no hace nada (no pisa datos que ya hayas cargado).
--
-- apellido/cargo estan vacios a proposito: el formulario de "Mi Perfil"
-- para esta cuenta especifica solo pide Nombre, Telefono y LinkedIn
-- (index.html se encarga de eso). Completa telefono y LinkedIn desde
-- ahi despues de correr esto.

insert into inscripciones (nombre, apellido, email, telefono, cargo, empresa, perfil_visible)
select 'HK Human Capital', '', 'comunidadhk901@gmail.com', '', '', 'HK Human Capital', true
where not exists (
  select 1 from inscripciones where lower(email) = lower('comunidadhk901@gmail.com')
);
