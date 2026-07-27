-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
--
-- Arregla un problema real: las policies de insercion (inscribirse y
-- subir CV) solo estaban permitidas para el rol "anon". Si alguien
-- abre el formulario publico en el mismo navegador donde quedo una
-- sesion de administrador iniciada, el request se manda como
-- "authenticated" en vez de "anon" y la insercion fallaba en
-- silencio. Ahora se permite ambos roles: cualquiera puede
-- inscribirse o subir su CV, este o no logueado como admin.

drop policy if exists "cualquiera puede inscribirse" on inscripciones;
create policy "cualquiera puede inscribirse"
  on inscripciones for insert
  to anon, authenticated
  with check (true);

drop policy if exists "cualquiera puede subir su cv" on storage.objects;
create policy "cualquiera puede subir su cv"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'cvs');
