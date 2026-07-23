# Handoff: Comunidad de Talento HK (sitio público)

## Overview
Plataforma pública donde profesionales se inscriben gratis a la comunidad de talento de HK Human Capital: landing, formulario de inscripción en 2 pasos, confirmación, y biblioteca de recursos de empleabilidad con vista de detalle. No incluye backend, autenticación, ni el panel administrativo (queda para una entrega posterior).

## About the Design Files
El archivo `Comunidad de Talento HK.dc.html` en este paquete es una **referencia de diseño en HTML** (prototipo funcional en frontend, sin backend real). No es código de producción para copiar tal cual. La tarea es **recrear este diseño en el stack del proyecto destino** (React/Next, Vue, etc. — o el framework que el equipo defina si no existe uno aún), usando sus propios componentes, sistema de estilos y convenciones.

## Fidelity
**Alta fidelidad (hifi)**: colores, tipografía, espaciado e interacciones están definidos y deben respetarse pixel a pixel. Todo el contenido de copy (textos en español) es final, salvo los recursos de ejemplo de la biblioteca, que son contenido de muestra (ver sección Contenido de ejemplo).

## Pantallas / Vistas
Todas viven en un solo archivo con navegación por estado (`page` interno): `landing`, `form1`, `form2`, `confirmation`, `library`, `detail`.

### 1. Landing (Inicio)
- **Propósito**: presentar la propuesta de valor y llevar a inscripción o a la biblioteca.
- **Header**: logo HK a la izquierda, nav (Inicio, Comunidad, Recursos, Nosotros) centrado/derecha, botón "Únete a la comunidad" (naranjo). Menú hamburguesa en <880px.
- **Barra de acento**: franja de 4px con degradé naranjo→celeste bajo el header, en todas las pantallas.
- **Hero**: fondo degradé diagonal cálido (`#fdece0` → `#faf8f4`). Layout dos columnas (texto 460px min / imagen 420px min), colapsa a una columna en mobile. Eyebrow "Comunidad de Talento HK" en celeste; H1 serif 32–52px (clamp); párrafo 18px; dos botones (primario naranjo "Unirme a la comunidad", secundario outline "Explorar recursos"); imagen placeholder 420px alto, bordes redondeados 8px.
- **Beneficios**: grid 4 tarjetas (auto-fit, min 250px), fondo blanco, borde 1px `#ece7dd`, radio 6px, hover: eleva 4px + sombra naranjo suave + borde `#f0c9a4`. Cada tarjeta: barra naranja 36×2px + texto 16px semibold.
- **Cómo funciona**: fondo degradé blanco→celeste muy suave, 3 pasos en círculos numerados (52px, fondo `#faf1e7`, número serif naranjo).
- **Recursos destacados**: grid de 6 tarjetas (mismo patrón que biblioteca, ver abajo), con link "Ver toda la biblioteca →".
- **Confianza y privacidad**: sección fondo oscuro `#24262b`, texto claro, 4 bullets con punto naranjo, mensaje de confidencialidad.

### 2. Formulario de inscripción — Paso 1 (Información personal)
- Barra de progreso 2 segmentos (activo = degradé naranjo→celeste, inactivo = gris `#ece7dd`).
- Grid de campos (auto-fit min 240px): Nombre*, Apellido*, Email*, Teléfono*, Cargo actual*, Empresa actual* (obligatorios) + LinkedIn, Ciudad/país, Área profesional, Años de experiencia (opcionales).
- Inputs: borde `#d8d2c6`, radio 4px, focus → borde naranjo.
- Botón "Continuar" ancho completo, naranjo, hover con leve scale.

### 3. Formulario — Paso 2 (Perfil profesional)
- Dropzone de CV (PDF opcional): borde punteado, cambia de texto/check al cargar archivo.
- Chips de "Áreas de interés" (7 categorías), toggle individual, seleccionado = fondo naranjo sólido.
- Checkboxes: aceptar política de privacidad (obligatorio) y recibir comunicaciones (opcional), dentro de card blanca con borde.
- Validación: sin aceptar privacidad, muestra error en rojo y no avanza.
- Botones "Volver" (outline) y "Unirme a la Comunidad HK" (naranjo, flex 2).

### 4. Confirmación
- Ícono check en círculo naranjo, título + mensaje de bienvenida centrados, dos CTAs (Explorar recursos / Volver al inicio).

### 5. Biblioteca de recursos
- Buscador de texto (ancho completo) + chips de categoría (8: Todas + 7 categorías), seleccionado = fondo oscuro `#24262b`.
- Grid de tarjetas (auto-fit min 280px): categoría (celeste) · separador · tipo (gris), título serif 19px, descripción 14px gris, botón "Ver contenido →" en naranjo.
- Mensaje de "sin resultados" si el filtro no encuentra nada.

### 6. Detalle de recurso
- Breadcrumb "← Biblioteca de recursos".
- Pills de categoría (fondo celeste claro) y tipo (fondo naranjo claro).
- Título serif 34px, imagen de portada placeholder 340px, dos párrafos de cuerpo.
- Botón "Descargar [tipo]" solo si `downloadable: true`.
- Sección "Recursos relacionados" (hasta 3, misma categoría), tarjetas con hover elevación.

### Footer (todas las páginas)
Logo, tagline, LinkedIn, columna Legal (Política de privacidad, Términos y condiciones), columna Contacto (email, teléfono), línea inferior con copyright y "Acceso administradores" discreto (enlace futuro al login admin).

## Interacciones y comportamiento
- Navegación 100% client-side vía estado `page` (sin rutas de URL reales — el handoff debe implementar routing real, ej. `/`, `/unirme`, `/recursos`, `/recursos/:id`).
- Hover: nav links → naranjo; botones primarios → oscurece + scale 1.03; tarjetas → translateY(-4px) + sombra + borde de color.
- Focus en inputs → borde naranjo, sin outline default.
- El formulario es un flujo lineal de 2 pasos con barra de progreso; "Volver" no pierde los datos ya ingresados (mismo estado en memoria).
- Búsqueda y filtro de categoría en biblioteca son reactivos (sin debounce necesario, dataset pequeño).
- Sin animaciones de entrada/scroll; solo transiciones CSS de 0.2s en hover.

## Manejo de estado
- Estado del formulario: objeto único con todos los campos (personal + profesional), incluyendo `areasInteres` (array), `cvFileName` (string|null), dos checkboxes booleanos.
- Estado de biblioteca: `search` (string), `selectedCategory` (string), `selectedResourceId` (para detalle).
- No hay llamadas a red: todo el dataset de recursos vive en un array estático en el frontend (ver "Contenido de ejemplo").
- **Pendiente para desarrollo real**: persistencia de inscripciones (candidato: nombre, apellido, email, teléfono, cargo, empresa, linkedin, ciudad, área, años, CV, áreas de interés, consentimientos, fecha) y de contenidos (CRUD), típicamente vía Supabase u otro backend — no está implementado en este prototipo.

## Design Tokens

### Colores
- Naranjo marca (primario/CTA): `#E17B2F` / hover `#C86420`
- Naranjo claro (acento secundario): `#f5a35c`
- Celeste marca (secundario, links, categoría): `#1d6f9c` / hover `#155579`
- Fondo cálido hero: `#fdece0` → `#faf8f4` (degradé)
- Fondo base: `#faf8f4`
- Blanco tarjetas/header: `#ffffff`
- Texto principal: `#24262b`
- Texto secundario: `#3f4247`
- Texto terciario/gris: `#767b82`, `#9a958a`
- Bordes: `#ece7dd`, `#d8d2c6`
- Sección oscura (confianza): `#24262b`, texto `#e4e6e9` / `#c7cbd1`
- Error: `#c0392b`
- Pills categoría (fondo `#eaf3f8` / texto `#1d6f9c`), pills tipo (fondo `#fdf1e6` / texto `#b5601f`)

### Tipografía
- Serif (títulos): "Newsreader", pesos 400/500/600, tamaños 19–52px
- Sans (cuerpo/UI): "Public Sans", pesos 400/500/600/700, tamaños 13–18px

### Espaciado / radios
- Radio estándar de tarjetas/inputs/botones: 4–8px; chips/pills: 12–20px (pill)
- Padding de sección: 48px horizontal desktop, 24px mobile; secciones verticales 80–96px
- Gap de grids: 20–24px

### Sombras (hover)
- Tarjetas: `0 14px 28px rgba(225,123,47,0.14)` (tono naranjo) o `0 12px 24px rgba(225,123,47,0.12)`

## Assets
- Logo: `assets/hk-logo.png` (proporcionado por el usuario).
- Imágenes de hero y de portada de recursos: **placeholders** (`image-slot.js`, componente drag-and-drop) — el usuario debe reemplazar con fotografía real de HK (liderazgo, desarrollo de talento ejecutivo, evitar imágenes de stock genéricas).
- Fuentes: Google Fonts "Newsreader" y "Public Sans" (cargadas por `<link>`).

## Contenido de ejemplo
El array de 14 recursos (título, categoría, tipo, descripción, cuerpo) en el archivo es contenido de muestra/placeholder para poblar el diseño — reemplazar por contenido real de HK Human Capital antes de producción.

## Pendiente / fuera de este alcance
- Panel administrativo (login, dashboard, gestión de candidatos, gestión de contenidos) — no incluido en este entregable.
- Persistencia real de datos (base de datos, storage de CVs) y autenticación.
- Envío de emails de confirmación/bienvenida.

## Archivos
- `Comunidad de Talento HK.dc.html` — diseño completo (todas las pantallas públicas en un solo archivo, navegación por estado interno).
- `assets/hk-logo.png` — logo de HK Human Capital.
- `image-slot.js` — utilidad de placeholder de imagen usada en el prototipo (no es necesaria en la reconstrucción; solo referencia visual de dónde van las imágenes).
