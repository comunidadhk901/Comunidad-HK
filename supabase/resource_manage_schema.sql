-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/resource_content_schema.sql y
-- supabase/resource_enabled_schema.sql ya se hayan ejecutado antes.
--
-- A partir de este cambio, resource_content pasa a ser la fuente de
-- verdad de QUE recursos existen, en que orden y con que categoria/
-- tipo -- no solo su contenido editable. Esto permite agregar,
-- eliminar y reordenar recursos desde el sitio, sin tocar codigo.

alter table resource_content add column if not exists category text;
alter table resource_content add column if not exists "type" text;
alter table resource_content add column if not exists sort_order integer;

-- Los administradores tambien pueden eliminar recursos.
drop policy if exists "admins pueden eliminar contenido de recursos" on resource_content;
create policy "admins pueden eliminar contenido de recursos"
  on resource_content for delete
  to authenticated
  using (is_admin());

-- Semilla de los 14 recursos originales (categoria, tipo y orden).
-- Si ya editaste el titulo/descripcion/cuerpo de alguno (por ejemplo
-- "Como actualizar tu CV"), eso NO se toca: solo se completan
-- categoria/tipo/orden si todavia estan vacios, y solo se inserta el
-- resto de campos para filas que no existian antes.
insert into resource_content (slug, title, desc_text, body_one, category, "type", sort_order, enabled) values
  ('cv-guide', 'Cómo actualizar tu CV', 'Una guía práctica para ordenar tu experiencia y destacar logros relevantes para roles de liderazgo.', 'Un CV ejecutivo debe priorizar resultados por sobre funciones. Cuantifica el impacto de tu gestión: crecimiento, eficiencia, equipos liderados.

Mantén un formato limpio y de una a dos páginas. Actualízalo cada seis meses, incluso si no estás buscando un cambio activamente.', 'Currículum', 'Guía', 1, true),
  ('entrevista-ejecutiva', 'Cómo preparar una entrevista ejecutiva', 'Claves para presentar tu trayectoria con seguridad frente a un directorio o comité ejecutivo.', 'Una entrevista ejecutiva evalúa criterio y visión, no solo experiencia técnica. Prepara ejemplos concretos de decisiones que hayas tomado bajo presión y sus resultados medibles.

Investiga a fondo a la organización y a quienes te entrevistarán. Llega con preguntas que demuestren pensamiento estratégico, no solo interés en el cargo.', 'Entrevistas', 'Artículo', 2, false),
  ('transicion-laboral', 'Cómo enfrentar una transición laboral', 'Recomendaciones para gestionar el cambio de rol o industria con claridad y confianza.', 'Toda transición comienza con un diagnóstico honesto: qué buscas, qué estás dispuesto a soltar y qué te hace un candidato diferenciado.

Activa tu red profesional de forma genuina y ordenada. La mayoría de los movimientos ejecutivos surgen de relaciones de confianza, no de postulaciones abiertas.', 'Transición laboral', 'Artículo', 3, false),
  ('tendencias-mercado', 'Tendencias del mercado laboral', 'Un panorama de las habilidades y perfiles con mayor demanda en el mercado ejecutivo chileno.', 'Las organizaciones buscan cada vez más perfiles con capacidad de liderar transformación y ambigüedad, más allá del dominio técnico.

La movilidad entre industrias ha aumentado: la experiencia funcional profunda pesa más que la trayectoria dentro de un solo sector.', 'Mercado laboral', 'Artículo', 4, false),
  ('desarrollo-liderazgo', 'Desarrollo de liderazgo', 'Una conversación breve sobre cómo evolucionar de gerente a líder de alto impacto.', 'Liderar equipos en contextos complejos exige pasar de dar respuestas a formular las preguntas correctas.

El liderazgo se desarrolla con retroalimentación honesta y práctica deliberada, no solo con la experiencia acumulada.', 'Liderazgo', 'Video', 5, false),
  ('negociacion-renta', 'Negociación de renta', 'Cómo prepararte para conversar condiciones de renta con seguridad y criterio.', 'Antes de negociar, define tu rango de referencia con datos de mercado actualizados, no solo con tu expectativa personal.

Considera la propuesta de forma integral: renta fija, variable, beneficios y proyección, no solo el número base.', 'Negociación y renta', 'Guía', 6, false),
  ('plantilla-cv', 'Plantilla de CV ejecutivo', 'Un formato editable para ordenar tu trayectoria de forma clara y profesional.', 'Esta plantilla organiza tu experiencia por impacto y resultados, siguiendo el estándar que utilizan los procesos de executive search.

Incluye secciones para logros cuantificables, formación y referencias, listas para adaptar a tu perfil.', 'Currículum', 'Plantilla', 7, false),
  ('preguntas-entrevistas-directorio', 'Preguntas frecuentes en entrevistas de directorio', 'Ejemplos de preguntas habituales en procesos de alta dirección y cómo abordarlas.', 'Los comités de búsqueda suelen indagar en decisiones difíciles y en cómo gestionaste sus consecuencias.

Responder con estructura —contexto, decisión, resultado— transmite claridad y dominio de tu propia trayectoria.', 'Entrevistas', 'Video', 8, false),
  ('liderar-incertidumbre', 'Liderar equipos en tiempos de incertidumbre', 'Principios para sostener la confianza de un equipo durante procesos de cambio.', 'La incertidumbre exige comunicación más frecuente, no menos. La ambigüedad se gestiona con transparencia sobre lo que se sabe y lo que no.

Los equipos siguen a líderes que muestran calma y consistencia, incluso cuando no tienen todas las respuestas.', 'Liderazgo', 'Artículo', 9, false),
  ('plan-carrera-5-anos', 'Cómo construir un plan de carrera a 5 años', 'Un marco para definir objetivos profesionales de mediano plazo con foco e intención.', 'Un plan de carrera sólido parte de identificar el tipo de impacto y responsabilidad que quieres tener, no solo el cargo al que aspiras.

Revisa tu plan cada año: las prioridades cambian, y tu plan de carrera debe evolucionar contigo.', 'Desarrollo de carrera', 'Guía', 10, false),
  ('mentoring-ejecutivo', 'Mentoring: por qué todo ejecutivo lo necesita', 'El rol del mentoring en la toma de decisiones y el crecimiento profesional sostenido.', 'Contar con un mentor externo a tu organización aporta una mirada sin sesgos internos sobre tus decisiones.

El mentoring más valioso no da respuestas: ayuda a formular mejores preguntas sobre tu propio camino.', 'Desarrollo de carrera', 'Artículo', 11, false),
  ('historias-transicion', 'Historias de transición: directivos que dieron el salto', 'Testimonios sobre decisiones de cambio de industria o de rol en etapas clave de carrera.', 'Quienes han transitado con éxito entre industrias coinciden en algo: prepararon su narrativa antes de buscar el cambio.

La transición se vive con menos incertidumbre cuando se apoya en una red de confianza y en asesoría especializada.', 'Transición laboral', 'Video', 12, false),
  ('checklist-oferta-laboral', 'Checklist: evalúa una oferta laboral', 'Una lista de verificación para analizar una propuesta más allá de la renta.', 'Una oferta se evalúa en conjunto: cultura, proyección, equipo, condiciones y alineación con tus objetivos de carrera.

Usa este checklist antes de responder a una propuesta, para tomar una decisión informada y sin apuro.', 'Mercado laboral', 'Plantilla', 13, false),
  ('beneficios-mas-alla-sueldo', 'Beneficios más allá del sueldo: qué negociar', 'Elementos de la propuesta total que suelen pasarse por alto en una negociación.', 'Renta variable, bonos de ingreso, flexibilidad y desarrollo también son parte legítima de una negociación.

Negociar con transparencia y datos de respaldo fortalece la relación con tu futuro empleador, no la debilita.', 'Negociación y renta', 'Artículo', 14, false)
on conflict (slug) do update set
  category = coalesce(resource_content.category, excluded.category),
  "type" = coalesce(resource_content."type", excluded."type"),
  sort_order = coalesce(resource_content.sort_order, excluded.sort_order);
