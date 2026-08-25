-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/contactado_schema.sql ya se haya ejecutado antes.
--
-- No agrega policies nuevas: las columnas nuevas quedan cubiertas por la
-- policy de UPDATE para admins que ya existe sobre toda la tabla
-- inscripciones ("admins pueden actualizar inscripciones").

-- Quien marco como contactado cada solicitud, y cuando.
alter table inscripciones add column if not exists coaching_contactado_por text;
alter table inscripciones add column if not exists coaching_contactado_at timestamptz;
alter table inscripciones add column if not exists outplacement_contactado_por text;
alter table inscripciones add column if not exists outplacement_contactado_at timestamptz;

-- Confirmacion manual del admin de que la persona ya quedo cargada en la
-- base de datos/CRM de HK (fuera de este sitio).
alter table inscripciones add column if not exists en_base_datos boolean not null default false;
