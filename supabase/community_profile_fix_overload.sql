-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/community_profile_photo_schema.sql ya se haya ejecutado antes.
--
-- community_profile_photo_schema.sql agrego el parametro p_foto_updated_at a
-- update_my_profile. En Postgres, "create or replace function" solo reemplaza
-- una funcion con la MISMA firma (mismos parametros): al agregar uno nuevo,
-- en realidad creo una funcion SOBRECARGADA nueva en vez de reemplazar la
-- anterior, y quedaron las dos coexistiendo. Eso causa el error "Could not
-- choose the best candidate function" al guardar el perfil. Esto elimina la
-- version vieja (13 parametros, sin la foto) y deja solo la version nueva.

drop function if exists update_my_profile(text,text,text,text,text,text,text,text,text,text,text,text,text);
