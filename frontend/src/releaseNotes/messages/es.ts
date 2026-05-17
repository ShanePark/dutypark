import type { ReleaseNoteId } from '../meta'
import type { ReleaseNotesMessages } from '../types'

export const esReleaseNotes = {
  title: "Cambios",
  count: "{count} cambios",
  loadMore: "Ver más",
  latest: "Más reciente",
  pr: "PR #{number}",
  openedAt: "Fecha del PR",
  areas: "Áreas",
  categories: {
    feature: "Función",
    improvement: "Mejora",
    fix: "Corrección",
    maintenance: "Mantenimiento",
    security: "Seguridad"
  },
  areaLabels: {
    admin: "Administración",
    attachments: "Adjuntos",
    auth: "Autenticación",
    calendar: "Calendario",
    dashboard: "Panel",
    docs: "Documentos",
    duty: "Turnos",
    friends: "Amigos",
    guide: "Guía",
    infra: "Infraestructura",
    localization: "Idiomas",
    maintenance: "Mantenimiento",
    notifications: "Notificaciones",
    policy: "Políticas",
    profile: "Perfil",
    schedule: "Agenda",
    security: "Seguridad",
    team: "Equipo",
    todo: "Todo",
    ui: "Interfaz"
  },
  entries: {
    "pr-369": {
      title: "Actualizar el icono de la app Dutypark",
      summary: "Cambia el icono de la app por el diseño elegido de calendario con luna y añade rutas de icono con renovación de caché.",
      changes: [
        "Reemplaza el favicon, Apple touch icon, iconos Android/PWA, mosaico MS, máscara Safari y marca SVG con el nuevo diseño de calendario con luna.",
        "Usa iconos con esquinas transparentes y nombres de archivo versionados para que los navegadores y las PWA instaladas carguen limpiamente el nuevo arte.",
        "Añade el nuevo icono junto al logotipo de texto Dutypark en el encabezado autenticado."
      ]
    },
    "pr-368": {
      title: "Aclara los estados de lectura de notificaciones",
      summary: "Hace que las notificaciones leídas y no leídas sean más fáciles de distinguir y mantiene visibles las acciones en móvil.",
      changes: [
        "Notificaciones del encabezado: muestra la acción de marcar todo como leído cuando hay elementos no leídos cargados y añade bordes visibles al botón.",
        "Lista de notificaciones: añade indicadores de no leído con barra de acento, punto en el avatar y más contraste en el título.",
        "Acciones móviles: añade etiquetas localizadas cortas para que las acciones de lectura y eliminación sigan visibles en pantallas estrechas."
      ]
    },
    "pr-367": {
      title: "Validar las notas de versión del PR antes de fusionar",
      summary: "Agrega las notas faltantes de la corrección de botones y una comprobación de PR que detecta entradas de notas de versión faltantes antes de fusionar.",
      changes: [
        "Agrega los metadatos de la nota de versión del PR #366 y el texto localizado en los idiomas compatibles.",
        "Agrega una comprobación de CI basada en el número de PR que falla cuando un PR hacia main no tiene metadatos o texto localizado de notas de versión.",
        "Documenta el flujo de crear primero el PR y luego agregar el commit de notas de versión."
      ]
    },
    "pr-366": {
      title: "Normalizar los botones de acción de los modales",
      summary: "Evita que las acciones de guardar en los modales de Todo y agenda se colapsen en botones altos y estrechos en pantallas pequeñas.",
      changes: [
        "Detalle de Todo: reutiliza el pie compacto de acciones del modal en modo edición para que cancelar y guardar compartan el ancho disponible.",
        "Detalle de agenda: elimina un contenedor que encogía las acciones de crear/editar para mantener los botones horizontales en móvil."
      ]
    },
    "pr-364": {
      title: "Automatizar GitHub Releases desde notas de versión de la app",
      summary: "Crea GitHub Releases desde la nota de versión en inglés correspondiente cada vez que un PR se fusiona en main.",
      changes: [
        "Agrega un flujo de GitHub Release que se ejecuta en PR fusionados y admite ejecución manual para recuperación.",
        "Genera etiquetas, títulos y notas desde los metadatos de notas de versión y el texto en inglés en lugar del cuerpo del PR.",
        "Documenta el flujo futuro de notas de versión por PR y falla la preparación si falta la entrada en la app."
      ]
    },
    "pr-362": {
      title: "Agregar notas de versión en la app",
      summary: "Agrega un registro de cambios localizado en la guía con una nota por cada PR fusionado y validación para entradas futuras.",
      changes: [
        "Muestra las notas de versión al final de la página de guía con cinco entradas cargadas cada vez.",
        "Completa metadatos de notas de versión por PR y textos localizados para los idiomas compatibles.",
        "Agrega validación para metadatos duplicados, entradas de idioma faltantes y compilación de mensajes vue-i18n."
      ]
    },
    "pr-361": {
      title: "Mejorar la navegación del calendario y las lecturas de notificaciones.",
      summary: "Agregue navegación mensual reutilizable con gestos de deslizamiento para los encabezados del calendario.",
      changes: [
        "Calendario: agregue CalendarMonthNavigator y reutilícelo en los encabezados del calendario de tareas y de equipo con controles anterior/siguiente y acceso al selector de año y mes.",
        "Notificaciones: actualice las notificaciones desplegables al abrir, capture el ID de notificación único no leído y márquelo como leído al cerrar solo cuando siga siendo el mismo elemento único no leído.",
        "Copia y pruebas: agregue traducciones de etiquetas de aria del calendario y cobertura de Pinia para un comportamiento de lectura de notificaciones únicas no leídas."
      ]
    },
    "pr-359": {
      title: "Mostrar horarios idénticos una vez",
      summary: "Se muestran los detalles del cronograma de actualizaciones para que las horas de inicio y finalización idénticas se muestren una vez.",
      changes: [
        "Frontend: agregue un guardia al mismo tiempo en ScheduleList.vue antes de representar un rango de tiempo."
      ]
    },
    "pr-358": {
      title: "Agregue navegación deslizada animada al muelle móvil",
      summary: "Reemplace el flash instantáneo de estado activo de la base con un indicador de resaltado deslizante.",
      changes: [
        "Animación resaltada del muelle.",
        "Mueva el fondo del muelle activo a un indicador deslizante compartido que rastrea el elemento seleccionado.",
        "Vuelva a calcular el tamaño y la posición del indicador en los cambios de ruta, el renderizado inicial y el cambio de tamaño."
      ]
    },
    "pr-357": {
      title: "Actualización de dependencia: follow-redirects 1.15.11 -> 1.16.0",
      summary: "Se actualizaron los redireccionamientos de seguimiento del 1.15.11 al 1.16.0 en la interfaz.",
      changes: [
        "Se modificaron las redirecciones de seguimiento de 1.15.11 a 1.16.0.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-356": {
      title: "Actualización de dependencia: axios 1.13.5 -> 1.15.0",
      summary: "Axios actualizados de 1.13.5 a 1.15.0 en la interfaz.",
      changes: [
        "Axios mejorados de 1.13.5 a 1.15.0.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-355": {
      title: "Mejorar el calendario interactivo TODO y los chips del Día D",
      summary: "Muestre más títulos TODO del calendario antes de truncarlos en pantallas pequeñas.",
      changes: [
        "Fichas TODO del calendario.",
        "Cambie la representación TODO móvil al truncamiento basado en caracteres para que los títulos cortos permanezcan visibles.",
        "Conserve los títulos TODO completos a través de información sobre herramientas de chips y etiquetas de accesibilidad."
      ]
    },
    "pr-354": {
      title: "Mejore el tiempo de análisis de registros y actualice los agentes de usuario de tokens",
      summary: "Agregue registros de análisis de tiempo de programación más completos con solicitudes, contenido normalizado y detalles de tiempo analizado.",
      changes: [
        "Programe el análisis del tiempo.",
        "Agregue un asistente de respuesta que formatee la solicitud y los resultados del análisis en una sola línea de registro.",
        "Registre las rutas de análisis LLM y sin tiempo después de generar la respuesta final."
      ]
    },
    "pr-353": {
      title: "Actualización de dependencia: vite 7.3.1 -> 7.3.2",
      summary: "Vite actualizado de 7.3.1 a 7.3.2 en la interfaz.",
      changes: [
        "Vite desplazado de 7.3.1 a 7.3.2.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-351": {
      title: "Actualización de dependencia: lodash 4.17.21 -> 4.18.1",
      summary: "Lodash actualizado del 4.17.21 al 4.18.1 en la interfaz.",
      changes: [
        "Lodash modificado del 17.04.21 al 18.04.1.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-352": {
      title: "Corregir la desviación de la fecha local de la interfaz",
      summary: "Se corrigió el editor del día D y el flujo del calendario para que los valores locales de solo fecha ya no se desvíen un día.",
      changes: [
        "Día D de servicio: se reemplazó la división de fechas basada en UTC con análisis y formato de solo fecha local en el modal de día D, el modal de detalle, la coincidencia de calendario y la clasificación de listas.",
        "Panel de administración: extrajo el recuento de inicio de sesión con fecha local en un asistente dedicado y agregó cobertura de regresión para el caso anterior a las 9 a. m., hora de Corea.",
        "Utilidades TODO/date: se agregaron ayudantes seguros de solo fecha, representación de fecha de vencimiento Kanban actualizada y pruebas de fecha de interfaz extendidas para formato de solo fecha."
      ]
    },
    "pr-350": {
      title: "Estabilizar la paginación de búsqueda de horarios",
      summary: "Elimine la advertencia de paginación de recuperación de colección de Hibernate de la búsqueda programada.",
      changes: [
        "Divida la búsqueda de programación en una consulta de identificación de programación paginada y una búsqueda de detalles de seguimiento.",
        "Preservar el orden de resultados en el servicio al hidratar los horarios recuperados.",
        "Agregue cobertura de regresión para resultados etiquetados, metadatos de paginación y ordenamiento en el mismo momento de inicio."
      ]
    },
    "pr-349": {
      title: "Controles de comparación de derechos polacos y interfaz de usuario de búsqueda",
      summary: "Pula la experiencia de visualización de tareas con un estado activo más claro, acciones de reinicio en línea y chips de comparación con reconocimiento de perfil.",
      changes: [
        "Interfaz de usuario de comparación de tareas: se agregaron acciones claras en la barra de tipo de tareas y comparación modal, y se actualizaron los chips de otras tareas en la cuadrícula del calendario.",
        "Controles de búsqueda: refinó el campo de búsqueda del encabezado de tareas y eliminó el ícono redundante dentro de la entrada modal de búsqueda.",
        "Contrato API: se ampliaron otras respuestas deber con memberId, hasProfilePhoto y perfilPhotoVersion y se actualizó la cobertura del controlador."
      ]
    },
    "pr-348": {
      title: "Harden gemma-4 programa el análisis del tiempo y la configuración del tiempo de espera",
      summary: "Fortalezca el análisis del tiempo programado para las respuestas de Gemma-4 que anteponen el texto de razonamiento antes de la carga útil JSON final.",
      changes: [
        "Programe el análisis del tiempo.",
        "Extraiga el objeto JSON con forma de respuesta final incluso cuando aparezca un texto de razonamiento o un JSON de ejemplo delante de él.",
        "Agregue pruebas de regresión para el análisis de respuesta de Gemma-4 y extienda el tiempo de espera de las pruebas de integración del análisis."
      ]
    },
    "pr-347": {
      title: "Estilo de tarjeta de amigo polaco en el tablero y en las vistas de amigos",
      summary: "Elimine el tratamiento innecesario en segundo plano de la programación de las tarjetas de amigos del panel.",
      changes: [
        "Panel de control.",
        "Elimine el fondo de programación adicional de las líneas de programación de amigos en la lista de tarjetas del panel.",
        "Reemplace el abrupto cambio de gradiente del encabezado del tablero con una transición de superposición más suave."
      ]
    },
    "pr-346": {
      title: "Reforzar las reglas de visibilidad y respaldo de autenticación",
      summary: "Reforzar las rutas alternativas de autenticación para que el cierre de sesión y las solicitudes autenticadas sigan funcionando correctamente cuando las cookies sean las únicas credenciales válidas.",
      changes: [
        "Autenticación y seguridad.",
        "Permita el cierre de sesión a través de la ruta de la cookie del token de actualización y alinee la cobertura de documentos/controlador de autenticación con el contrato de tiempo de ejecución.",
        "Recurra a la cookie del token de acceso cuando se proporcione un token de portador incorrecto para que la autenticación de la cookie válida aún se realice correctamente."
      ]
    },
    "pr-345": {
      title: "Reforzar el manejo de respaldo de notificaciones",
      summary: "Agregue alternativas genéricas de carga útil de notificaciones para flujos no leídos, paginados y marcados como leídos en lugar de descartar o rechazar filas no válidas.",
      changes: [
        "Parte trasera.",
        "Devuelve cargas útiles genéricas de la versión 0 para cargas útiles de notificaciones faltantes o no válidas.",
        "Cambie el nombre de los métodos de recuento de notificaciones internas en torno a solicitudes de relaciones pendientes."
      ]
    },
    "pr-344": {
      title: "Mover el error de API y la representación push detallada al frontend",
      summary: "Mueva la copia de error de API localizada y la representación detallada de notificaciones push a rutas i18n propiedad del frontend.",
      changes: [
        "Frontend i18n y renderizado push.",
        "Mueva los asistentes de configuración regional a utilidades de interfaz compartidas y mantenga abierto el conmutador de configuración regional después de descartar el flujo de sugerencias de configuración regional.",
        "Doble la copia de error de API en los paquetes de mensajes locales y agregue notificaciones del lado frontal y ayudantes de renderizado push."
      ]
    },
    "pr-343": {
      title: "Mover el renderizado y las notificaciones de i18n al frontend",
      summary: "Mueva la representación de notificaciones, la copia push y la localización de errores de API del backend a rutas de código propiedad del frontend.",
      changes: [
        "Arquitectura de notificación.",
        "Reemplace el título de notificación almacenado y el texto del contenido con instantáneas de carga útil escritas más control de versiones de la carga útil.",
        "Agregue DTO de notificación de interfaz, registro de renderizador y claves de mensaje versionadas para cada mensaje de notificación."
      ]
    },
    "pr-342": {
      title: "Agregue localización en inglés y japonés para toda la aplicación",
      summary: "Agregue una infraestructura de localización de front-end para toda la aplicación con paquetes de mensajes en coreano, inglés y japonés.",
      changes: [
        "Interfaz i18n.",
        "Agregue la configuración de Vue i18n, el manejo de la tienda local y el flujo de sugerencias de idiomas para usuarios nuevos.",
        "Localice el panel, las tareas, las tareas pendientes, el equipo, el administrador, la guía, la notificación, la autenticación, la política y los componentes/modales compartidos."
      ]
    },
    "pr-341": {
      title: "Relax calendario móvil truncamiento del Día D",
      summary: "Relaje el truncamiento del día D del calendario móvil para que los títulos sigan siendo legibles durante más tiempo antes de colapsar en puntos suspensivos.",
      changes: [
        "Calendario frontend/servicios.",
        "Agregue un asistente de truncamiento de texto móvil compartido para contenido de celda de calendario compacto.",
        "Aplique la regla de truncamiento móvil a los títulos del día D en DutyCalendarContent."
      ]
    },
    "pr-338": {
      title: "Mejorar los detalles compartidos del día del calendario y las sugerencias de visibilidad",
      summary: "Abra un modo de detalle de día único de solo lectura para calendarios compartidos, de modo que los horarios y las etiquetas permanezcan legibles durante mucho tiempo.",
      changes: [
        "Detalle del día calendario compartido.",
        "Reemplace el flujo emergente de detalles del calendario compartido por programación con el modal de detalles del día de solo lectura.",
        "Mantenga el pie de página de detalles del día compartido en estado de solo lectura con una simple acción de cierre."
      ]
    },
    "pr-337": {
      title: "Sincronizar la selección de tareas detalladas del día por fecha",
      summary: "Mantenga los botones de servicio de detalles del día sincronizados con la fecha del calendario seleccionada actualmente.",
      changes: [
        "Haga que el día de trabajo seleccionado en DutyView sea reactivo al día seleccionado actual y a los datos de deberes en lugar de almacenar una instantánea obsoleta.",
        "Restablezca el estado de selección de servicio local de DayDetailModal cuando cambie la fecha seleccionada o la propiedad de servicio entrante.",
        "Elimine la asignación de tareas única del controlador de clics del día para que los datos modales siempre reflejen el estado del último mes."
      ]
    },
    "pr-336": {
      title: "Actualización de dependencia: picomatch 4.0.3 -> 4.0.4",
      summary: "Picomatch actualizado de 4.0.3 a 4.0.4 en el frontend.",
      changes: [
        "Picomatch mejorado de 4.0.3 a 4.0.4.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-335": {
      title: "Unificar patrones modales de frontend",
      summary: "Unifique los shells modales, los encabezados, los cuerpos y el espaciado de acciones de pie de página en toda la interfaz.",
      changes: [
        "Fundamento modal común.",
        "Amplíe BaseModal para un estilo de panel compartido.",
        "Agregue clases de utilidad de entrada/acción/cuerpo modal compartido en frontend/src/style.css."
      ]
    },
    "pr-334": {
      title: "Estandarice los shells modales y las celdas de calendario de servicio móviles compactas",
      summary: "Estandarice el tamaño del shell modal, la superposición y el área segura en cuadros de diálogo compartidos y específicos de funciones.",
      changes: [
        "Frontend/Fundación modal.",
        "Agregue un componente BaseModal compartido con opciones de manejo de tamaño, altura, relleno de superposición, índice z y fondo.",
        "Mueva la superposición modal y el tamaño de los contenedores a utilidades CSS compartidas, incluidos los medianes seguros para las ventanas gráficas y las variantes de relleno seguras para la navegación."
      ]
    },
    "pr-333": {
      title: "Agregar etiquetas de tareas pendientes y actualizaciones de estado de miembros etiquetados",
      summary: "Agregue etiquetas de tareas para que los propietarios puedan etiquetar a amigos y los miembros etiquetados puedan actualizar el estado de las tareas en todos los ámbitos y flujos de tareas.",
      changes: [
        "Parte trasera.",
        "Agregue persistencia de etiquetas de tareas pendientes, campos DTO, puntos finales del controlador y lógica de servicio para la creación y eliminación de etiquetas y cambios de estado de miembros etiquetados.",
        "Permita movimientos de tareas pendientes de estado únicamente cuando un miembro etiquetado cambie de columna y extienda los permisos de archivos adjuntos para contextos TODO."
      ]
    },
    "pr-332": {
      title: "Mejorar la heurística de reabastecimiento de la fecha de creación del miembro",
      summary: "Vuelva a trabajar la migración de recuperación de la fecha de creación del miembro para que ya no dependa del historial del token de actualización.",
      changes: [
        "Backend/Migración.",
        "Agregue una migración de reabastecimiento para la recuperación de member.created_date.",
        "Infiera marcas de tiempo de programación anteriores a partir de UUID heredados y de identificaciones de programación respaldadas por ULID cuando las columnas de auditoría de programación antiguas se aplanaron debido a una migración anterior."
      ]
    },
    "pr-331": {
      title: "Agregar modo de estadísticas detalladas de miembros administradores",
      summary: "Agregue una API y un modal de detalles de miembro administrador que muestre estadísticas de cuenta, actividad, programación, tareas pendientes, relación, día D y notificaciones.",
      changes: [
        "API de backend/administrador.",
        "Agregue GET /admin/api/members/{'{'}memberId{'}'} con campos de detalles de miembros agregados.",
        "Recopile recuentos de sesiones, horarios, tareas pendientes, amigos, gerente, día D y notificaciones para el miembro seleccionado."
      ]
    },
    "pr-330": {
      title: "Diseño de chip de etiqueta de programación polaca y acciones de lista",
      summary: "Mejore el tamaño y el espaciado de los chips de etiquetas de programación en la lista de programación, el calendario de tareas y el selector de etiquetas de amigos.",
      changes: [
        "Frontend / Lista de programación.",
        "Vuelva a trabajar el encabezado del elemento del programa para que las acciones de edición, eliminación y eliminación de etiquetas permanezcan agrupadas sin alterar el diseño del chip de etiquetas.",
        "Permita que los chips de miembros etiquetados utilicen el ancho disponible de manera más confiable dentro de la lista de programación."
      ]
    },
    "pr-329": {
      title: "Diseño modal de detalles del día móvil en polaco y edición de etiquetas",
      summary: "Reequilibre el espaciado modal de los detalles del día móvil y el manejo del área segura para que los modos de edición y lista de programación se ajusten mejor a las ventanas gráficas del tamaño de un iPhone.",
      changes: [
        "Interfaz.",
        "Convierta el modo de detalle del día en un diseño de hoja inferior móvil más confiable con espaciado entre shell/pie de página específico del modo y controles de formulario de programación más amplios.",
        "Ajuste FriendTagSelector, programe chips de etiquetas y presentación de etiquetas de calendario para la edición móvil, incluido el comportamiento de hacer clic para editar del chip de etiquetas."
      ]
    },
    "pr-328": {
      title: "Mejorar la programación del etiquetado de amigos y las vistas previas de miembros etiquetados",
      summary: "Mejore la forma en que se seleccionan, mantienen y muestran las etiquetas de amigos programadas en las superficies de tareas, calendario y panel de control.",
      changes: [
        "Interfaz.",
        "Agregue un FriendTagSelector reutilizable con búsqueda, filtrado solo de seleccionados, confirmación de reinicio, reserva de etiquetas no disponibles y diseños de lista/chip responsivos.",
        "Actualice los formularios de programación, listas, modales, contenido del calendario y vistas relacionadas de cara a los miembros para mostrar avatares de amigos etiquetados y una presentación de etiquetas más limpia."
      ]
    },
    "pr-326": {
      title: "Manejar errores de intercambio de tokens de Naver OAuth",
      summary: "Solucione las fallas de intercambio de tokens de Naver OAuth en producción conectando las variables de entorno del contenedor de aplicaciones que faltan.",
      changes: [
        "Operaciones.",
        "Pase NAVER_CLIENT_ID y NAVER_CLIENT_SECRET al contenedor de la aplicación de producción.",
        "Parte trasera."
      ]
    },
    "pr-325": {
      title: "Agregue el inicio de sesión social de Naver y normalice los enlaces de cuentas sociales",
      summary: "Agregue soporte de inicio de sesión social de Naver en los flujos de inicio de sesión/registro de backend y SPA.",
      changes: [
        "Backend OAuth: agregue configuración de Naver OAuth, clientes de token/información de usuario, manejo de devolución de llamadas y excepciones específicas de cuentas sociales.",
        "Registro y vinculación: requiera términos explícitos/versiones de privacidad, refuerce el manejo de enlaces sociales duplicados y preserve los campos de respuesta DTO existentes a través de un ensamblador dedicado.",
        "Persistencia: agregue, rellene los ID de Kakao/Naver heredados y luego elimine las columnas de miembros heredados en la migración de seguimiento."
      ]
    },
    "pr-324": {
      title: "Migrar estilos de temas codificados a clases de utilidad simbólicas",
      summary: "Migre enlaces de estilo y color codificados estáticos/en línea a clases de utilidad de token dp-* compartidas en toda la interfaz de Vue.",
      changes: [
        "Refactorización de tema/token.",
        "Reemplace los literales directos de estilo/color en las vistas y componentes principales con clases de utilidad y variables tokenizadas.",
        "Amplíe la cobertura del token en frontend/src/style.css (incluido el token de borde de entrada)."
      ]
    },
    "pr-323": {
      title: "Fortalecer la sincronización de la insignia de notificación de PWA de iOS",
      summary: "Fortalezca la sincronización de la insignia de la aplicación PWA de iOS al reanudar la aplicación.",
      changes: [
        "Tienda de notificaciones frontend.",
        "Se agregó una sólida lógica de respaldo de insignias de aplicaciones para las API de insignias de navegador y trabajador de servicios.",
        "Se agregaron activadores de sincronización de currículum para el enfoque y la presentación de páginas, además del cambio de visibilidad."
      ]
    },
    "pr-322": {
      title: "Sincronizar la insignia de la aplicación iOS PWA con el recuento de no leídos del servidor",
      summary: "Corrija los recuentos obsoletos de insignias de aplicaciones PWA de iOS cuando las notificaciones se leyeron en otro dispositivo.",
      changes: [
        "Tienda de notificaciones frontend.",
        "Llame a la sincronización de la insignia de la aplicación inmediatamente después de las respuestas de API de recuento no leído.",
        "Llame a la sincronización de la insignia de la aplicación cuando se obtenga la lista de no leídos."
      ]
    },
    "pr-320": {
      title: "Actualización de dependencia: paquete acumulativo 4.55.1 -> 4.59.0",
      summary: "Paquete acumulativo actualizado de 4.55.1 a 4.59.0 en la interfaz.",
      changes: [
        "Resumen mejorado de 4.55.1 a 4.59.0.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-321": {
      title: "Eliminar el token PAT requerido del proceso de pago de CI",
      summary: "Elimine el uso obligatorio del token PAT al finalizar la compra para que las solicitudes de extracción del Dependabot puedan ejecutar CI sin acceso secreto al repositorio.",
      changes: [
        "Flujo de trabajo de CI (.github/workflows/gradle.yml).",
        "Token eliminado: ${'{'}{'{'} secrets.PAT_TOKEN {'}'}{'}'} del paso de pago.",
        "Se mantuvieron los submódulos: recursivo y profundidad de búsqueda: 0 sin cambios."
      ]
    },
    "pr-319": {
      title: "Fortalezca los controles de visibilidad del Día D y reduzca el ruido de Slack",
      summary: "Haga cumplir las comprobaciones de visibilidad del calendario antes de atender los puntos finales de lectura del Día D.",
      changes: [
        "Mantenga intacto el comportamiento de filtrado privado del Día D después de las comprobaciones de visibilidad.",
        "Excluya MethodArgumentTypeMismatchException de las notificaciones de error de Slack.",
        "Refactorice la política de excepciones ignoradas en una colección dedicada para facilitar el mantenimiento."
      ]
    },
    "pr-317": {
      title: "Actualización de dependencia: axios 1.13.2 -> 1.13.5",
      summary: "Axios actualizados de 1.13.2 a 1.13.5 en la interfaz.",
      changes: [
        "Axios mejorados de 1.13.2 a 1.13.5.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-318": {
      title: "Utilice JPEG en lugar de PNG para fotos de perfil recortadas",
      summary: "Profile photo crop was converting images to PNG (lossless), inflating file size significantly (e.g., 2.9MB JPEG → 10MB+ PNG).",
      changes: [
        "Esto excedió nginx client_max_body_size 10M, lo que provocó errores 413 de contenido demasiado grande.",
        "Se cambió a JPEG con calidad 0.9, manteniendo los tamaños de archivo pequeños y manteniendo la calidad visual."
      ]
    },
    "pr-316": {
      title: "Enviar notificación de inactividad sobre el error de análisis de LLM",
      summary: "Agregue una notificación de Slack cuando falle el análisis del tiempo de LLM.",
      changes: [
        "Agregue los campos errorMessage y rawResponse para analizar la respuesta para la depuración.",
        "Agregue pruebas para excepciones y casos de falla de análisis."
      ]
    },
    "pr-314": {
      title: "Divida los componentes grandes de Vue y cargue el panel por lotes",
      summary: "Divida el componente DutyView grande en componentes más pequeños y enfocados (DDayList, DutyCalendarContent, DutyHeaderControls, DutyTodoRow, DutyTypesBar, ScheduleForm, ScheduleList, UntagConfirmModal).",
      changes: [
        "Divida TeamManageView en componentes modales separados (BatchUploadModal, DutyTypeModal, MemberSearchModal).",
        "Divida DayDetailModal en componentes más pequeños para una mejor mantenibilidad.",
        "Carga programada del panel por lotes para reducir las consultas N+1."
      ]
    },
    "pr-313": {
      title: "Mejore la cobertura de las pruebas y optimice la base de código",
      summary: "Amplíe la cobertura de pruebas para controladores y servicios en múltiples módulos.",
      changes: [
        "Pruebas: se agregaron pruebas integrales para los módulos de administración, archivos adjuntos, autenticación, panel, deber, miembro, notificación, política, inserción, programación, seguridad, equipo y todo.",
        "Rendimiento: se reemplazó el filtrado en memoria con una subconsulta de base de datos en MemberRepository.",
        "Calidad del código: se eliminaron las declaraciones de registrador no utilizadas y las declaraciones de registro detalladas."
      ]
    },
    "pr-311": {
      title: "Agregar soporte para notificaciones push web",
      summary: "Agregue soporte de notificación Web Push para solicitudes de amigos/familiares y etiquetas de programación.",
      changes: [
        "Backend: WebPushService, PushController, configuración VAPID.",
        "Frontend: Service Worker, usePushNotification composable, push API client.",
        "Base de datos: agregue columnas de inserción a la tabla refresco_token."
      ]
    },
    "pr-309": {
      title: "Mejore la experiencia de usuario del tablero de tareas pendientes y solucione problemas de posicionamiento del calendario/tareas pendientes",
      summary: "Mejore el diseño del tablero de tareas pendientes con desplazamiento de columnas independiente para una mejor experiencia de usuario.",
      changes: [
        "Se corrigió el cálculo de la posición de tareas pendientes al moverse entre columnas mediante arrastrar y soltar.",
        "Restablezca la fecha a hoy al cambiar de calendario y oculte los controles de etiquetas en el calendario de otras personas."
      ]
    },
    "pr-308": {
      title: "Correcciones de seguridad y mejoras de UX",
      summary: "Agregue un mensaje de estado vacío para la sección de amigos en el panel.",
      changes: [
        "Enmascare la clave API de Gemini en la salida del registro por seguridad.",
        "Maneje el vencimiento de la sesión de suplantación con un temporizador de cuenta regresiva y restauración automática.",
        "Valide la propiedad de DutyType antes de las operaciones de gestión del equipo para evitar el acceso no autorizado."
      ]
    },
    "pr-307": {
      title: "Agregar función auxiliar de creación de cuenta",
      summary: "Agregue una función de creación de cuenta auxiliar para administrar cronogramas de negocios secundarios o secundarios.",
      changes: [
        "Add POST /api/members/auxiliary endpoint in MemberController.",
        "Agregue el método createAuxiliaryAccount en MemberService.",
        "Agregue la función API createAuxiliaryAccount en member.ts."
      ]
    },
    "pr-306": {
      title: "Correcciones de degradación familiar, modal de tareas pendientes y zona horaria",
      summary: "Agregue la capacidad de degradar a un miembro de la familia a amigo normal.",
      changes: [
        "Se corrigió la apertura modal de detalles de tareas pendientes al hacer clic en tareas pendientes en el calendario.",
        "Se solucionó el problema de la zona horaria que mostraba las 09:00 para las fechas de vencimiento de solo fecha."
      ]
    },
    "pr-305": {
      title: "Optimice el análisis del tiempo de programación de IA con prefiltro y límites de velocidad configurables",
      summary: "Agregue un filtro previo para omitir llamadas de LLM para horarios sin indicadores de tiempo (números, palabras en tiempo coreano como 한/두/세, 정오/자정).",
      changes: [
        "Extraiga los límites de velocidad de IA codificados (rpm/rpd) a la configuración de application.yml.",
        "Aumente los límites de velocidad de 10 RPM/20 RPD a 30 RPM/14400 RPD."
      ]
    },
    "pr-304": {
      title: "Cambie del modelo Gemini al modelo Gemma con indicaciones mejoradas",
      summary: "Cambie el modelo de IA de Gemini 2.5 Flash Lite a Gemma 3 27B debido a la cuota gratuita reducida de Gemini.",
      changes: [
        "ScheduleTimeParsingService.kt: reemplace el mensaje basado en instrucciones con un mensaje basado en ejemplos.",
        "Application.yml: cambia el modelo de gemini-2.5-flash-lite a gemma-3-27b-it.",
        "ScheduleTimeParsingServiceTest.kt: actualice la prueba para verificar que los números de piso no se analicen como tiempo."
      ]
    },
    "pr-303": {
      title: "Actualice Spring Boot 4.0 y Gemini 2.5 Flash",
      summary: "Actualice Spring Boot de 3.5.6 a 4.0.1 con cambios de dependencia relacionados.",
      changes: [
        "Arranque de primavera 3.5.6 → 4.0.1.",
        "Primavera AI 1.0.3 → 2.0.0-M1.",
        "Módulo Jackson: com.fasterxml.jackson.module → tools.jackson.module."
      ]
    },
    "pr-302": {
      title: "Actualice Java 21 a 25",
      summary: "Actualice la cadena de herramientas Java de 21 a 25.",
      changes: [
        "Actualice Kotlin de 2.1.10 a 2.3.0 (compatible con destino Java 25 JVM).",
        "Actualice Gradle de 8.11 a 9.2.1 (compatibilidad con Java 25).",
        "Actualice el complemento asciidoctor de 3.3.2 a 4.0.5."
      ]
    },
    "pr-301": {
      title: "Mejoras en el frontend: integración del calendario de tareas pendientes, limpieza de código y corrección de errores",
      summary: "Muestre todos con fechas de vencimiento en la vista de calendario para una mejor visibilidad.",
      changes: [
        "Elimine el código inactivo y las funciones API heredadas no utilizadas de la interfaz.",
        "Simplifique la interfaz de usuario del filtro de tareas pendientes (IN_PROGRESS siempre se muestra, solo alternar TODO).",
        "Solucione el problema de sincronización con los recuentos de tipos de tareas mediante el uso de propiedades calculadas."
      ]
    },
    "pr-300": {
      title: "Agregar tablero kanban para la gestión de tareas pendientes",
      summary: "Agregue una vista de tablero kanban (/todo) con soporte para arrastrar y soltar para la gestión de tareas pendientes.",
      changes: [
        "Nueva página de tablero kanban TodoBoardView.vue con diseño responsivo.",
        "Componentes KanbanCard.vue y KanbanColumn.vue para arrastrar y soltar.",
        "Alternar filtro de tareas pendientes para visibilidad de elementos completados/retenidos."
      ]
    },
    "pr-296": {
      title: "Agregue limitación de la tasa de inicio de sesión para evitar ataques de fuerza bruta",
      summary: "Implemente una limitación de la tasa de inicio de sesión basada en base de datos con una combinación de IP + correo electrónico.",
      changes: [
        "Agregue la entidad LoginAttempt y el repositorio para realizar un seguimiento de los intentos fallidos.",
        "Agregue LoginAttemptService con límites configurables (intentos máximos, duración de la ventana).",
        "Integrate rate limiting into AuthService and AuthController."
      ]
    },
    "pr-295": {
      title: "Mejorar la lista de sesiones de administración y las mejoras en la interfaz de usuario del calendario.",
      summary: "Agregue animación de brillo de pulso para resaltar la fecha del calendario para mejorar la retroalimentación visual.",
      changes: [
        "Mejore la lista de sesiones de administración con una interfaz de usuario plegable y un mejor estilo.",
        "Agregue la fecha de creación a la lista de tokens de sesión para una mejor gestión de tokens."
      ]
    },
    "pr-294": {
      title: "Consolide las variables CSS y mejore el estilo del modo oscuro",
      summary: "Consolide las variables CSS y elimine la duplicación del modo oscuro para un mantenimiento más limpio.",
      changes: [
        "Corrija la navegación para corregir la fecha al hacer clic en programar notificación en la página del calendario.",
        "Mejore la visibilidad del borde del botón de tipo de servicio en modo oscuro."
      ]
    },
    "pr-293": {
      title: "Mejore los componentes de la interfaz de usuario, agregue una guía del usuario y refactorice los estilos modales",
      summary: "Agregue una página de guía del usuario completa (/guide) con secciones plegables que cubren todas las funciones de la aplicación.",
      changes: [
        "Nueva función: página de guía del usuario con documentación de ayuda para Panel de control, Calendario, Equipo, Amigos y Configuración.",
        "Refactor: estilos modales comunes extraídos de style.css para lograr coherencia en todos los modales.",
        "Solución: el efecto de desplazamiento de la cuadrícula del calendario ahora respeta el elemento en el que se puede hacer clic (deshabilitado en calendarios de solo visualización)."
      ]
    },
    "pr-292": {
      title: "Resolver problemas de banner de suplantación y menú desplegable de notificaciones",
      summary: "Se corrigió que el banner de suplantación estuviera oculto por un encabezado fijo.",
      changes: [
        "Se corrigieron los eventos de clic del menú desplegable de notificaciones que no funcionan debido a problemas de contexto de apilamiento del índice z.",
        "Incluya el título del programa en el título de la notificación SCHEDULE_TAGGED."
      ]
    },
    "pr-291": {
      title: "Agregue sistema de notificación, página de amigos y encabezado fijo",
      summary: "Agregue un sistema de notificación con actualizaciones basadas en encuestas.",
      changes: [
        "Agregue una página de administración de amigos dedicada y simplifique el panel.",
        "Agregue una insignia de recuento de solicitudes de amistad y mejore la navegación de notificaciones.",
        "Haga que el encabezado sea fijo en la parte superior con el botón de alternancia de tema."
      ]
    },
    "pr-289": {
      title: "Actualización de dependencia: preact 10.27.2 -> 10.28.2",
      summary: "Preact actualizado de 10.27.2 a 10.28.2 en la interfaz.",
      changes: [
        "Preact modificado de 10.27.2 a 10.28.2.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-290": {
      title: "Agregue colores de íconos basados en visibilidad y limpie el código no utilizado",
      summary: "Agregue colores de íconos basados en la visibilidad para la creación de horarios (el ícono de candado refleja la configuración de privacidad).",
      changes: [
        "Elimine el código no utilizado en el backend y el frontend (21 archivos, -249 líneas netas)."
      ]
    },
    "pr-288": {
      title: "Mejorar el diseño del escaparate de introducción y el posicionamiento de la maqueta.",
      summary: "Agregue margen entre el título del héroe y el subtítulo para mejorar el espaciado.",
      changes: [
        "Se corrige el tamaño del marco de la maqueta para que sea coherente en todas las funciones (200 px para dispositivos móviles, 260 px para escritorio).",
        "Elimine las animaciones de transformación de la maqueta para un posicionamiento estable durante el desplazamiento.",
        "Agregue altura mínima al área de texto para evitar cambios de posición de la maqueta entre secciones."
      ]
    },
    "pr-287": {
      title: "Página de introducción estilo Apple con animaciones de desplazamiento",
      summary: "Agregue una página de introducción al estilo de Apple con animaciones de desplazamiento y páginas de privacidad/términos.",
      changes: [
        "Agregue una sección de héroe con efectos de entrada animados.",
        "Implemente un escaparate de desplazamiento adhesivo para resaltar las funciones.",
        "Las funciones permanecen centradas mientras se desplaza con transiciones de fundido cruzado al 80-100% de progreso."
      ]
    },
    "pr-286": {
      title: "Agregue modo de entrada de servicio secuencial con botones rápidos",
      summary: "Agregue el modo de entrada de tareas secuencial para una edición de tareas más rápida.",
      changes: [
        "Agregue un concepto de día enfocado (comienza el día 1 en el modo de edición).",
        "Mostrar navegador de día con botones de flecha ``.",
        "Haga clic en el botón de servicio → aplicar al día enfocado → pasar automáticamente al día siguiente."
      ]
    },
    "pr-285": {
      title: "Agregar control de versiones de la URL de la foto de perfil para eliminar el caché",
      summary: "Agregue una estrategia de control de versiones de URL para la gestión del caché de fotos de perfil.",
      changes: [
        "Agregue la columna perfil_foto_versión a través de la migración Flyway (V2.1.3).",
        "Agregue el campo perfilPhotoVersion a la entidad miembro con el método de incremento.",
        "Actualice ProfilePhotoService para incrementar la versión al cargar."
      ]
    },
    "pr-284": {
      title: "Elimine el código no utilizado y solucione problemas de coherencia de los datos",
      summary: "Elimine los métodos y tipos no utilizados en el backend y el frontend.",
      changes: [
        "Elimine el método no utilizado MemberDto.ofSimple().",
        "Elimine los métodos no utilizados AttachmentRepository.findFirstByContextTypeAndContextId() y existByContextTypeAndContextId().",
        "Elimine SimpleMemberD al constructor secundario innecesario."
      ]
    },
    "pr-283": {
      title: "Agregar suplantación de cuenta para miembros administrados",
      summary: "Agregue la funcionalidad de suplantación/restauración que permita a los administradores cambiar a cuentas administradas.",
      changes: [
        "Agregue los campos isImpersonating y originalMemberId a LoginMember.",
        "Agregue compatibilidad con el token de suplantación JWT en JwtProvider.",
        "Agregue los puntos finales POST /api/auth/impersonate/{'{'}targetMemberId{'}'} y POST /api/auth/restore."
      ]
    },
    "pr-282": {
      title: "Agregue paginación del lado del servidor y optimice el análisis del agente de usuario",
      summary: "Agregue paginación del lado del servidor a la lista de miembros administradores con búsqueda antirrebote.",
      changes: [
        "Agregue AdminMemberDto con información de miembro y tokens asociados.",
        "Agregue AdminService con consulta de miembro paginado.",
        "Agregue consultas personalizadas de MemberRepository con NULLS LAST para una clasificación adecuada."
      ]
    },
    "pr-281": {
      title: "Mejore la experiencia de usuario modal de búsqueda y agregue efectos de desplazamiento",
      summary: "Agregue la funcionalidad de búsqueda en modal para volver a buscar sin cerrar el modal.",
      changes: [
        "Agregue un campo de entrada de búsqueda en el encabezado modal para cambiar la consulta de búsqueda.",
        "Agregue un indicador de estado de carga durante la búsqueda.",
        "Reduzca la altura modal en PC (70vh) para una mejor visibilidad."
      ]
    },
    "pr-280": {
      title: "Mejoras en el calendario y limpieza de código.",
      summary: "Agregue navegación rápida al mes actual en el calendario de tareas (haga clic en el botón de pie de página o en el nombre del miembro).",
      changes: [
        "Corrija CalendarView para que siempre devuelva 42 días (6 semanas) para un diseño consistente.",
        "Utilice la API de calendario backend en la interfaz para una alineación adecuada del índice con los días festivos.",
        "Evite solicitudes duplicadas de Kakao OAuth con clics rápidos."
      ]
    },
    "pr-279": {
      title: "Migrar la autenticación de localStorage a cookies HttpOnly",
      summary: "Migre el almacenamiento de tokens de localStorage a cookies HttpOnly para protección XSS.",
      changes: [
        "Agregue CookieConfig.kt y CookieService.kt para la gestión de cookies.",
        "Actualice AuthController para configurar las cookies HttpOnly al iniciar sesión/actualizar.",
        "Agregue el requisito {'@'}Login para cerrar sesión en el punto final."
      ]
    },
    "pr-278": {
      title: "Simplifique la interfaz de usuario de tareas pendientes y mejore el diseño del calendario",
      summary: "Simplifique la interfaz de usuario de la lista de tareas pendientes eliminando la función de arrastrar y soltar.",
      changes: [
        "Elimine la función de arrastrar y soltar de SortableJS de las burbujas de tareas pendientes.",
        "Convierta a un diseño de lista simple en el que se puede hacer clic con un estilo compacto.",
        "Reduzca la complejidad visual manteniendo la funcionalidad."
      ]
    },
    "pr-277": {
      title: "Migrar a la arquitectura Vue 3 SPA",
      summary: "Vue 3 SPA con API de composición y TypeScript.",
      changes: [
        "Vite para un servidor de desarrollo rápido con HMR (Reemplazo de módulo en caliente).",
        "Pinia para la gestión estatal.",
        "Tailwind CSS 4 con tokens de diseño personalizados."
      ]
    },
    "pr-276": {
      title: "Consolidar el cargador de archivos adjuntos y actualizar la documentación",
      summary: "Consolide la inicialización duplicada del cargador Uppy en un asistente compartido.",
      changes: [
        "Extraiga ~300 líneas de lógica de inicialización de Uppy duplicada de 3 archivos modales en la función createUppyUploader en adjunto-helpers.js.",
        "Reducción total de código: 764 líneas (38%).",
        "Archivos afectados:."
      ]
    },
    "pr-274": {
      title: "Agregue archivos adjuntos de tareas pendientes y corrija las advertencias del servidor",
      summary: "Agregue la función de archivo adjunto a TODO (cargar, descargar, eliminar).",
      changes: [
        "Agregue la funcionalidad de carga de archivos con la integración de Uppy.",
        "Agregar botón de descarga para archivos adjuntos.",
        "Agregue la funcionalidad de eliminación de archivos adjuntos."
      ]
    },
    "pr-269": {
      title: "Optimice la búsqueda de días festivos en la inicialización de tareas",
      summary: "Optimice el rendimiento de las búsquedas en días festivos eliminando las llamadas API redundantes durante la inicialización del servicio entre semana.",
      changes: [
        "Antes: llamado HolidayService.findHolidays() para cada fecha en la vista de calendario (N veces).",
        "Después: llame una vez y cree un conjunto para la búsqueda O(1).",
        "Reduce la complejidad del tiempo de O(n²) a O(n)."
      ]
    },
    "pr-268": {
      title: "Implementar un sistema de adjuntos de horarios con carga, generación de miniaturas y control de permisos.",
      summary: "Carga de archivos con integración de Uppy.js y gestión de sesiones de carga.",
      changes: [
        "Generación automática de miniaturas para imágenes (asincrónica con seguimiento de estado).",
        "Control de acceso basado en permisos para archivos adjuntos.",
        "Visor de imágenes en línea para archivos adjuntos de horarios."
      ]
    },
    "pr-267": {
      title: "Mejorar la reactividad de Vue y las mejoras de UX",
      summary: "Solucione el problema de reactividad de Vue.js en el método hasSchedule.",
      changes: [
        "Cambie hasSchedule del patrón de función de orden superior al método directo para garantizar un seguimiento adecuado de la reactividad de Vue.",
        "Resuelve el problema por el cual la clase CSS has-schedule se aplicaba incorrectamente.",
        "Omita la llamada API y la ventana emergente de éxito al seleccionar el tipo de tarea ya asignada."
      ]
    },
    "pr-266": {
      title: "Mejorar la calidad y la seguridad del código base",
      summary: "Actualice jjwt a 0.12.6 con API actualizada para mejoras de seguridad.",
      changes: [
        "Agregue el atributo de cookie SameSite=Lax para protección CSRF.",
        "Reemplace AntPathRequestMatcher en desuso con AntPathMatcher.",
        "Mejore las respuestas de error 404 con mensajes de error detallados."
      ]
    },
    "pr-265": {
      title: "Mostrar solo todos activos de forma predeterminada en la descripción general",
      summary: "Mostrar solo todos activos de forma predeterminada en el modo de descripción general.",
      changes: [
        "Establezca el valor predeterminado todoOverviewFilters.completed en falso en duty.js.",
        "Actualice la pantalla de recuento de tareas pendientes para mostrar solo el recuento de tareas pendientes."
      ]
    },
    "pr-264": {
      title: "Habilitar descripción general para arrastrar y reordenar",
      summary: "Permitir arrastrar todos activos dentro del modo de descripción general con un identificador familiar.",
      changes: [
        "Sincronice el reordenamiento entre la descripción general y la lista principal y mantenga el orden en el backend."
      ]
    },
    "pr-263": {
      title: "Agregue controles giratorios de carga para mejorar la experiencia de usuario",
      summary: "Agregue indicadores de estado de carga para evitar cambios de diseño y mejorar la experiencia de usuario.",
      changes: [
        "Lista de tareas pendientes: muestra la rueda giratoria mientras se cargan todas en lugar de parpadear en estado vacío.",
        "Panel de control - Mi información: agregue un control giratorio para el tipo de tarea y los datos de programación, mantenga visibles los elementos estáticos (fecha, etiquetas).",
        "Panel de control - Lista de amigos: agregue un control giratorio durante la búsqueda de datos de amigos."
      ]
    },
    "pr-262": {
      title: "Evitar el enfoque automático en la entrada modal del tipo de tarea para dispositivos móviles",
      summary: "Refactorización de la inicialización modal del tipo de tarea para evitar el enfoque automático en Safari móvil.",
      changes: [
        "Agregue la función initDutyTypeModal() para evitar la ventana emergente del teclado en Safari móvil.",
        "Utilice un atributo temporal de solo lectura para bloquear el enfoque automático durante la inicialización modal.",
        "Aplique desenfoque() para garantizar que la entrada pierda el foco inmediatamente en la apertura modal."
      ]
    },
    "pr-261": {
      title: "Seguimiento de finalización de tareas pendientes y mejoras modales",
      summary: "Agregue seguimiento del estado de finalización de tareas pendientes con estados ACTIVO/COMPLETADO.",
      changes: [
        "Agregue la enumeración TodoStatus (ACTIVO, COMPLETADO).",
        "Agregue seguimiento de la fecha de finalización.",
        "Agregue puntos finales para completar/reabrir todos (PATCH /api/todos/{'{'}id{'}'}/complete, /reopen)."
      ]
    },
    "pr-260": {
      title: "Mejore la gestión del tipo de tareas con el selector de color y la optimización móvil",
      summary: "Reemplace la enumeración de colores con un selector de color personalizado usando la biblioteca Pickr para una selección de colores ilimitada.",
      changes: [
        "Agregue una vista previa en tiempo real en los modos de tipo de servicio que muestran el color y el nombre seleccionados.",
        "Optimice los modales para un diseño centrado en dispositivos móviles con fuentes más grandes y controles táctiles.",
        "Implemente clases de utilidad Bootstrap sobre estilos en línea en toda la aplicación."
      ]
    },
    "pr-259": {
      title: "El administrador ahora puede buscar en el calendario del administrador",
      summary: "Refactor: optimice el análisis del tiempo programado con filtrado temprano de contenido.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, programación, equipo y amigos relacionados para esta versión."
      ]
    },
    "pr-257": {
      title: "Mejoras en la interfaz de usuario y correcciones de errores para la selección y programación de amigos",
      summary: "Se solucionó el problema de desplazarse hacia arriba al etiquetar amigos en el modo de programación.",
      changes: [
        "Solucionar el problema de desplazamiento de etiquetado de amigos: se cambió href=\"#\" a href=\"javascript:void(0)\" para evitar el desplazamiento de página.",
        "UX de selección de amigos mejorada: se agregaron efectos de desplazamiento y puntero del cursor para una mejor respuesta de interacción.",
        "Comportamiento fijo de las casillas de verificación: permite deseleccionar las casillas marcadas incluso cuando se alcanza la selección máxima."
      ]
    },
    "pr-254": {
      title: "Agregue soporte para dutyType nulo y bandera explícita de día libre en...",
      summary: "... deberes.",
      changes: [
        "Se actualizaron las rutas de código de equipo, panel e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-253": {
      title: "Tipo de trabajo días laborables completados automáticamente por inicio diferido",
      summary: "Se agregaron días de semana de tipo de trabajo que se llenan automáticamente con inicio diferido.",
      changes: [
        "Se actualizaron las rutas de código de equipo, administración e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-252": {
      title: "Mostrar horarios de servicio combinados",
      summary: "Se agregaron programas de tareas combinadas.",
      changes: [
        "Se actualizaron las rutas de código relacionadas con la programación, los amigos, el panel y la interfaz de usuario para esta versión."
      ]
    },
    "pr-250": {
      title: "Algunas mejoras de diseño",
      summary: "Se mejoraron algunas mejoras de diseño.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-249": {
      title: "Divida duty.html en módulos con alcance de funciones",
      summary: "Se actualizó split duty.html en módulos con alcance de funciones.",
      changes: [
        "Se actualizaron las rutas de código relacionadas de Calendario, Programación, Todo, Equipo, Amigos y Panel de control para esta versión."
      ]
    },
    "pr-247": {
      title: "Experiencia de usuario de búsqueda mejorada",
      summary: "Se mejoró la experiencia de usuario de búsqueda.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-246": {
      title: "CalendarView.kt",
      summary: "CalendarView.kt actualizado.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, calendario, programación, equipo y calendario relacionados para esta versión."
      ]
    },
    "pr-245": {
      title: "Bocadillo de diálogo con detalles del horario",
      summary: "Cuando haga clic en el icono de programación de chat que tiene detalles de programación, se mostrará un texto emergente con detalles de programación.",
      changes: [
        "Puede editar la fecha de inicio del programa en el modo de edición del programa."
      ]
    },
    "pr-244": {
      title: "Cuando actualiza los Días D, muestra la modificación en el calendario a la derecha...",
      summary: "...lejos.",
      changes: [
        "Se actualizaron las rutas de código de Calendario relacionadas para esta versión."
      ]
    },
    "pr-243": {
      title: "Horario del equipo",
      summary: "Horario del equipo agregado.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, programación, tareas pendientes y de equipo relacionadas para esta versión."
      ]
    },
    "pr-242": {
      title: "Asegúrese de que Duty se elimine cuando se elimine DutyType",
      summary: "Se actualizó para garantizar que Duty se elimine cuando se elimine DutyType.",
      changes: [
        "Se actualizaron las notificaciones relacionadas y las rutas de código de infraestructura para esta versión."
      ]
    },
    "pr-241": {
      title: "Departamento => equipo",
      summary: "Departamento actualizado => equipo.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, programación, equipo y amigos relacionados para esta versión."
      ]
    },
    "pr-240": {
      title: "Revisión",
      summary: "Revisión mejorada.",
      changes: [
        "Se actualizaron las notificaciones relacionadas y las rutas del código del panel de control para esta versión."
      ]
    },
    "pr-239": {
      title: "mi pagina de equipo",
      summary: "Mejoré la página de mi equipo.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, programación, todo, equipo y amigos relacionados para esta versión."
      ]
    },
    "pr-238": {
      title: "Función de administrador",
      summary: "Función de administrador mejorada.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, programación, tareas pendientes y de equipo relacionadas para esta versión."
      ]
    },
    "pr-237": {
      title: "Menú activo en el muelle",
      summary: "Menú activo mejorado en el muelle.",
      changes: [
        "Se actualizó la programación relacionada y las rutas del código de interfaz de usuario para esta versión."
      ]
    },
    "pr-236": {
      title: "Utilice LLM para extraer datos de tiempo del título del cronograma",
      summary: "Uso mejorado de LLM para extraer datos de tiempo del título del cronograma.",
      changes: [
        "Se actualizaron las rutas de código de programación, tareas pendientes, equipo, amigos, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-235": {
      title: "Mejora menor de UI/UX",
      summary: "Mejora menor de UI/UX mejorada.",
      changes: [
        "Se actualizó el panel relacionado y las rutas de código de la interfaz de usuario para esta versión."
      ]
    },
    "pr-234": {
      title: "# corrección temporal",
      summary: "# corrección temporal mejorada.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, panel e interfaz de usuario relacionadas para esta versión."
      ]
    },
    "pr-233": {
      title: "Modificaciones menores de diseño.",
      summary: "Modificaciones menores de diseño mejoradas.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-226": {
      title: "Interfaz de usuario similar a una aplicación compatible con dispositivos móviles",
      summary: "Interfaz de usuario mejorada similar a una aplicación compatible con dispositivos móviles.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, amigos y UI relacionadas para esta versión."
      ]
    },
    "pr-225": {
      title: "Fijar amigo",
      summary: "Amigo pin mejorado.",
      changes: [
        "Se actualizaron las rutas relacionadas con el equipo, los amigos, el administrador, el panel, la interfaz de usuario y el código de infraestructura para esta versión."
      ]
    },
    "pr-224": {
      title: "Panel de control mejor UX",
      summary: "Tablero mejorado, mejor UX.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, programación, equipo, panel y UI relacionados para esta versión."
      ]
    },
    "pr-222": {
      title: "Servicio del departamento de carga por lotes",
      summary: "Se mejoró la tarea del departamento de carga por lotes.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, calendario, equipo, administrador, archivos adjuntos y panel relacionados para esta versión."
      ]
    },
    "pr-221": {
      title: "Panel de control",
      summary: "Panel de control TODO nuevo: panel para invitados, novatos sin departamento todavía.",
      changes: [
        "Se actualizaron las rutas de código relacionadas con Programación, Todo, Equipo, Amigos, Administrador y Panel de control para esta versión."
      ]
    },
    "pr-220": {
      title: "1. refactorización por lotes de tareas 2. muestra los recuentos de tareas",
      summary: "Refactorización por lotes de tareas Corrección de errores por lotes de tareas UI/UX mejorada Versión de Kotlin actualizada.",
      changes: [
        "Se actualizaron las rutas de código de infraestructura, interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-219": {
      title: "Automatizar las actualizaciones de horarios de trabajo a partir de horarios cargados",
      summary: "Se mejoró la automatización de las actualizaciones del horario de trabajo a partir de los horarios cargados.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, calendario, programación, equipo, administrador, archivos adjuntos relacionados para esta versión."
      ]
    },
    "pr-218": {
      title: "Archivo de redacción de base de datos de Dutypark",
      summary: "Archivo de redacción de base de datos de dutypark actualizado.",
      changes: [
        "Se actualizaron las rutas de código de archivos adjuntos, interfaz de usuario, infraestructura y documentos relacionados para esta versión."
      ]
    },
    "pr-213": {
      title: "Descripción del horario",
      summary: "Descripción del horario mejorada.",
      changes: [
        "Se actualizaron las rutas de código de infraestructura, calendario, interfaz de usuario y calendario relacionados para esta versión."
      ]
    },
    "pr-258": {
      title: "Migrar a una implementación basada en Docker con pila de monitoreo",
      summary: "Migre a una implementación basada en Docker con pila de monitoreo.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, programación, notificaciones y administración relacionadas para esta versión."
      ]
    },
    "pr-210": {
      title: "Despídase de ingresar[tipo=\"mes\"], evento de clic en el resultado de búsqueda",
      summary: "Se mejoró decir adiós a la entrada [tipo=\"mes\"], evento de clic en el resultado de búsqueda.",
      changes: [
        "Se actualizaron las rutas de código de calendario, programación, interfaz de usuario, infraestructura y documentos relacionados para esta versión."
      ]
    },
    "pr-208": {
      title: "Restringir los números de página en el resultado de búsqueda",
      summary: "En caso de que tuviera demasiadas páginas (más de 20), era demasiado ancha y el diseño era feo.",
      changes: [
        "Por lo tanto, restrinja las páginas para mostrar."
      ]
    },
    "pr-207": {
      title: "Programar búsqueda",
      summary: "Búsqueda de horarios mejorada.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, amigos y programación relacionadas para esta versión."
      ]
    },
    "pr-206": {
      title: "Actualización de lotes de derechos",
      summary: "Actualización de lotes de tareas mejorada.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-204": {
      title: "Arranque de primavera 3.3.5, JDK 21",
      summary: "Arranque de primavera mejorado 3.3.5, JDK 21.",
      changes: [
        "Se actualizó la interfaz de usuario relacionada y las rutas del código de infraestructura para esta versión."
      ]
    },
    "pr-202": {
      title: "Asegúrese de que los días D estén cargados antes de verificar las tareas en el calendario",
      summary: "Se corrigió que los días D se cargaran antes de verificar las tareas en el calendario.",
      changes: [
        "Se actualizaron las rutas de código de Calendario relacionadas para esta versión."
      ]
    },
    "pr-201": {
      title: "Hotfix corrige algunos errores y mejora la interfaz de usuario",
      summary: "Los cambios detallados se encuentran en sus mensajes de confirmación.",
      changes: [
        "Se actualizaron las rutas de código de UI, localización y notificaciones relacionadas para esta versión."
      ]
    },
    "pr-200": {
      title: "Función TODO",
      summary: "Función tODO mejorada.",
      changes: [
        "Se actualizaron las rutas de código relacionadas de Todo, UI, Infra y Docs para esta versión."
      ]
    },
    "pr-198": {
      title: "Error tipográfico",
      summary: "Error tipográfico corregido.",
      changes: [
        "Se actualizaron las rutas del código de mantenimiento relacionadas para esta versión."
      ]
    },
    "pr-196": {
      title: "Desalojar el caché de vacaciones al restablecer la información",
      summary: "Se corrigió el desalojo del caché de vacaciones al restablecer la información.",
      changes: [
        "Se actualizaron las rutas de código de Calendario relacionadas para esta versión."
      ]
    },
    "pr-195": {
      title: "No mostrar otros horarios en el modo de edición",
      summary: "Se corrigió que no mostrara otros horarios en el modo de edición.",
      changes: [
        "Se actualizaron las rutas de código de programación relacionadas para esta versión."
      ]
    },
    "pr-194": {
      title: "Actualización de dependencia: acciones/descargar-artefacto 2 -> 4.1.7",
      summary: "Acciones actualizadas/descarga-artefacto de 2 a 4.1.7 en .github/workflows.",
      changes: [
        "Acciones modificadas/artefacto de descarga de 2 a 4.1.7.",
        "Mantuvo el conjunto de dependencias actualizado para mantenimiento y seguridad."
      ]
    },
    "pr-193": {
      title: "Puede cambiar el nombre de servicio predeterminado",
      summary: "Agregado puede cambiar el nombre del deber predeterminado.",
      changes: [
        "Se actualizaron las rutas de código de equipo, administración e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-192": {
      title: "Mensaje de confirmación para quitar la etiqueta",
      summary: "Se agregó un mensaje de confirmación para quitar la etiqueta.",
      changes: [
        "Se actualizaron las rutas de código de programación relacionadas para esta versión."
      ]
    },
    "pr-191": {
      title: "Revisión (notificación de error de holgura, eliminación programada de UX)",
      summary: "Revisión mejorada (notificación de error de holgura, programación de eliminación de UX).",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, programación, amigos, notificaciones y UI relacionados para esta versión."
      ]
    },
    "pr-190": {
      title: "Archivo Bootstrap .map NoResourceFoundException resuelto",
      summary: "Se corrigió el archivo bootstrap .map NoResourceFoundException resuelto.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, programación, archivos adjuntos, interfaz de usuario e infraestructura relacionados para esta versión."
      ]
    },
    "pr-189": {
      title: "El nombre del miembro ya no es único",
      summary: "El nombre del miembro fijo ya no es único.",
      changes: [
        "Se actualizaron las rutas de código de infraestructura relacionadas para esta versión."
      ]
    },
    "pr-186": {
      title: "Crear robots.txt",
      summary: "Se mejoró la creación de robots.txt.",
      changes: [
        "Se actualizaron las rutas de código de infraestructura relacionadas para esta versión."
      ]
    },
    "pr-185": {
      title: "Migración de arranque de primavera 3.0 -> 3.2",
      summary: "Migración de arranque de primavera actualizada 3.0 -> 3.2.",
      changes: [
        "Se actualizó la interfaz de usuario relacionada y las rutas del código de infraestructura para esta versión."
      ]
    },
    "pr-184": {
      title: "Programar la fecha de finalización de la experiencia de usuario mejorada",
      summary: "En caso de que la fecha y hora de finalización se haya configurado automáticamente, si el usuario cambia la fecha y hora de inicio, la fecha y hora de finalización también la sigue.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, calendario y programación relacionadas para esta versión."
      ]
    },
    "pr-183": {
      title: "Error de posición de DutyType",
      summary: "Cuando obtenga la posición máxima, ya no use el tamaño de dutyTypes, pero busque el valor máximo.",
      changes: [
        "Se actualizaron las rutas de código del equipo relacionadas para esta versión."
      ]
    },
    "pr-182": {
      title: "Reordenación del tipo de servicio",
      summary: "Se agregó reordenamiento del tipo de servicio.",
      changes: [
        "Se actualizaron las rutas de código de administrador y equipo relacionadas para esta versión."
      ]
    },
    "pr-180": {
      title: "Error de cambio de posición en el programa",
      summary: "No se pueden reorganizar los horarios etiquetados cerca del n.° 175.",
      changes: [
        "Se actualizaron las rutas de código de programación relacionadas para esta versión."
      ]
    },
    "pr-179": {
      title: "Eliminar el botón \"cerrar\" en el modo de detalle del horario",
      summary: "Estaba confundiendo a la gente al agregar el horario.",
      changes: [
        "Se actualizó la programación relacionada y las rutas del código de interfaz de usuario para esta versión."
      ]
    },
    "pr-178": {
      title: "#estilo: desplácese hacia abajo cuando agregue un nuevo horario",
      summary: "#estilo agregado: desplácese hacia abajo cuando agregue un nuevo horario.",
      changes: [
        "Se actualizó la programación relacionada y las rutas del código de interfaz de usuario para esta versión."
      ]
    },
    "pr-177": {
      title: "Kakao SSO Iniciar sesión / registrarse",
      summary: "Se agregó kakao SSO Iniciar sesión/registrarse.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, programación, amigos, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-176": {
      title: "Error de carga asíncrona de amigos resuelto",
      summary: "Se corrigió el error asíncrono de carga de amigos resuelto.",
      changes: [
        "Se actualizaron las rutas de código de Friends relacionadas para esta versión."
      ]
    },
    "pr-174": {
      title: "Diseño de etiqueta ajustado",
      summary: "Diseño de etiqueta mejorado ajustado.",
      changes: [
        "Se actualizó la programación relacionada y las rutas del código de interfaz de usuario para esta versión."
      ]
    },
    "pr-173": {
      title: "Mejor diseño de calendario",
      summary: "El borde blanco era inútil cuando el color APAGADO era blanco.",
      changes: [
        "Entonces, todas las fronteras son negras a partir de ahora."
      ]
    },
    "pr-171": {
      title: "Implementar visibilidad del cronograma",
      summary: "Se agregó visibilidad del cronograma de implementos.",
      changes: [
        "Se actualizó la programación relacionada y las rutas de código de amigos para esta versión."
      ]
    },
    "pr-170": {
      title: "Refactorice el diseño del calendario con la clase 'fila 7' para un ancho consistente",
      summary: "Diseño de calendario de refactorización mejorado con clase 'fila 7' para un ancho consistente.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-169": {
      title: "Error de serialización del token de actualización resuelto",
      summary: "Se resolvió el error de serialización del token de actualización reforzado.",
      changes: [
        "Se actualizaron las rutas de acceso del código de seguridad y autenticación relacionadas para esta versión."
      ]
    },
    "pr-168": {
      title: "El huésped puede recuperar el calendario público",
      summary: "Los invitados mejorados pueden recuperar el calendario público.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, calendario, programación, amigos y de interfaz de usuario relacionados para esta versión."
      ]
    },
    "pr-167": {
      title: "Configuración de visibilidad para el propio calendario.",
      summary: "Configuración de visibilidad mejorada para el propio calendario.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, programación, equipo y amigos relacionados para esta versión."
      ]
    },
    "pr-165": {
      title: "Mejore el rendimiento mediante el almacenamiento en caché",
      summary: "Se corrigió la mejora del rendimiento mediante el almacenamiento en caché.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-163": {
      title: "Etiqueta a tus amigos según lo programado",
      summary: "Se mejoró etiquetar amigos según lo programado.",
      changes: [
        "Se actualizaron las rutas de código de programación, equipo, amigos, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-162": {
      title: "Horario a las 00:01 no muestra hora de inicio",
      summary: "00:01 - 00:01 debería mostrar la hora de inicio.",
      changes: [
        "También 00:00 - 00:01 deberían mostrar la hora de finalización."
      ]
    },
    "pr-161": {
      title: "Asignar a un miembro un departamento/eliminar",
      summary: "Error de transacción resuelto.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, administrador y equipo relacionadas para esta versión."
      ]
    },
    "pr-158": {
      title: "Eliminar columna de secuencia del Día D",
      summary: "Es problemático ordenar el día d.",
      changes: [
        "Simplemente déjelo ordenado por día."
      ]
    },
    "pr-153": {
      title: "amistad",
      summary: "Amistad mejorada.",
      changes: [
        "Se actualizaron las rutas relacionadas con el calendario, el equipo, los amigos, el administrador, la interfaz de usuario y el código de infraestructura para esta versión."
      ]
    },
    "pr-149": {
      title: "Notificación floja cuando la aplicación está lista y cerrada",
      summary: "Se agregó una notificación de holgura cuando la aplicación está lista y cerrada.",
      changes: [
        "Se actualizaron las rutas del código de notificaciones relacionadas para esta versión."
      ]
    },
    "pr-211": {
      title: "Actualizar los iconos de arranque versión v1.3.0 -> v1.11.0",
      summary: "Actualice los iconos de arranque versión v1.3.0 -> v1.11.0.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, calendario, programación, todo, equipo y amigos relacionados para esta versión."
      ]
    },
    "pr-251": {
      title: "Mejorar las etiquetas de programación que muestran la funcionalidad",
      summary: "Mejorar las etiquetas de programación que muestran la funcionalidad.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, panel y programación relacionadas para esta versión."
      ]
    },
    "pr-146": {
      title: "#ruta aérea",
      summary: "#ruta aérea actualizada.",
      changes: [
        "Se actualizó la interfaz de usuario relacionada y las rutas del código de infraestructura para esta versión."
      ]
    },
    "pr-144": {
      title: "Error al actualizar el administrador en el departamento.",
      summary: "Se corrigió el error al actualizar el administrador en el departamento.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, equipo y calendario relacionadas para esta versión."
      ]
    },
    "pr-143": {
      title: "Mejorar el diseño del calendario",
      summary: "Mejorado mejorar el diseño del calendario.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, calendario e interfaz de usuario relacionadas para esta versión."
      ]
    },
    "pr-147": {
      title: "Agregar índice en la ruta migratoria",
      summary: "Agregar índice en la ruta migratoria.",
      changes: [
        "Se actualizaron las rutas de código de infraestructura relacionadas para esta versión."
      ]
    },
    "pr-141": {
      title: "Caché de recursos estáticos",
      summary: "Recursos estáticos de caché mejorados.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, interfaz de usuario y documentos relacionados para esta versión."
      ]
    },
    "pr-140": {
      title: "Cambiar contraseña",
      summary: "Contraseña de cambio reforzada.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, administración, panel y interfaz de usuario relacionadas para esta versión."
      ]
    },
    "pr-139": {
      title: "Ya no usar CDN público para bibliotecas",
      summary: "Se actualizó que ya no se usa CDN público para bibliotecas.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, calendario, programación, tareas pendientes, amigos y notificaciones relacionadas para esta versión."
      ]
    },
    "pr-137": {
      title: "Solucione el efecto secundario de CSS e imprima el contenido del programa correctamente",
      summary: "Ahora el contenido programado se muestra correctamente cuando tiene varias líneas.",
      changes: [
        "Efecto secundario de CSS solucionado."
      ]
    },
    "pr-136": {
      title: "Hacer que los validadores funcionen",
      summary: "Validar parámetros del servidor.",
      changes: [
        "Validar límites de longitudes de entrada en web."
      ]
    },
    "pr-135": {
      title: "Agregue sincronización segura para subprocesos para evitar vacaciones duplicadas",
      summary: "Implemente ReentrantLock en loadAndSaveHolidaysFromAPI para gestionar la concurrencia.",
      changes: [
        "Garantice el acceso seguro para subprocesos a HolidayMap para evitar llamadas API duplicadas para el mismo año.",
        "Agregue comprobaciones para evitar solicitudes de API y operaciones de bases de datos redundantes si ya existen datos."
      ]
    },
    "pr-131": {
      title: "Corrección de errores de programación a lo largo del año",
      summary: "Cuando se recuperó el calendario de diciembre, se consideraba el próximo ENERO como el mes anterior, por lo que se solucionó.",
      changes: [
        "Se actualizaron las rutas de código de programación y calendario relacionadas para esta versión."
      ]
    },
    "pr-130": {
      title: "Límite de longitud del título (30) en la función del Día D",
      summary: "Se corrigió el límite de longitud del título (30) en la función del Día D.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-129": {
      title: "Se corrigió el error de índice al obtener una vista previa de las vacaciones del próximo mes.",
      summary: "Corrija el cálculo del día en CalendarView para obtener una vista previa precisa de los días del próximo mes en la vista del mes actual.",
      changes: [
        "Agregar método de prueba para diciembre de 2023."
      ]
    },
    "pr-127": {
      title: "No incluir el archivo clave en la ruta de clase",
      summary: "Asígnalo como texto y colócalo en la ruta del archivo.",
      changes: [
        "Se actualizaron los archivos adjuntos relacionados y las rutas de código de infraestructura para esta versión."
      ]
    },
    "pr-148": {
      title: "Agregar el botón \"hoy\" en el control mensual",
      summary: "Agregue el botón \"hoy\" en el control mensual.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-164": {
      title: "Eliminar brillo en el elemento de selección de safari",
      summary: "Eliminar brillo en el elemento seleccionado de safari.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-124": {
      title: "Sólo el miembro que haya iniciado sesión puede ver las tareas de los demás.",
      summary: "Existe una solución temporal hasta que se implemente la función de amigo.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad y amigos relacionadas para esta versión."
      ]
    },
    "pr-123": {
      title: "Error de rango de programación solucionado",
      summary: "Se corrigió el error en el rango de programación.",
      changes: [
        "Se actualizaron las rutas de código de programación relacionadas para esta versión."
      ]
    },
    "pr-122": {
      title: "Programar mejora CRUD UX",
      summary: "Se agregó la mejora CRUD UX del programa.",
      changes: [
        "Se actualizó la programación relacionada y las rutas del código de interfaz de usuario para esta versión."
      ]
    },
    "pr-121": {
      title: "DDNS en lugar de usar dirección IP directa",
      summary: "dDNS actualizado en lugar de usar la dirección IP directa.",
      changes: [
        "Se actualizaron las rutas de código de infraestructura relacionadas para esta versión."
      ]
    },
    "pr-142": {
      title: "Eliminar aplicación de filtro duplicada debido a la anotación {'@'}Component",
      summary: "Elimine la aplicación de filtro duplicada debido a la anotación {'@'}Component.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, programación y documentos relacionados para esta versión."
      ]
    },
    "pr-119": {
      title: "Algunas mejoras de estilo",
      summary: "Si DAY tiene algún horario, su fondo se vuelve más oscuro.",
      changes: [
        "El color del día público (pero no del día festivo) ya no es rojo."
      ]
    },
    "pr-126": {
      title: "Agregue el Día D en el calendario cuando esté incluido",
      summary: "Agregue el Día D en el calendario cuando esté incluido.",
      changes: [
        "Se actualizaron las rutas de código de Calendario relacionadas para esta versión."
      ]
    },
    "pr-117": {
      title: "Mientras edita el horario, oculta el botón \"agregar horario\"",
      summary: "Se corrigió al editar el horario, oculta el botón \"agregar horario\".",
      changes: [
        "Se actualizó la programación relacionada y las rutas del código de interfaz de usuario para esta versión."
      ]
    },
    "pr-120": {
      title: "Agregue un borde discontinuo en la parte superior al feriado (como el horario)",
      summary: "Agregue el borde superior discontinuo al día festivo (como el horario).",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, calendario y programación relacionadas para esta versión."
      ]
    },
    "pr-114": {
      title: "Información de vacaciones",
      summary: "Información de vacaciones mejorada.",
      changes: [
        "Se actualizaron las rutas relacionadas con seguridad, calendario, programación, notificaciones, interfaz de usuario y códigos de infraestructura para esta versión."
      ]
    },
    "pr-116": {
      title: "Corregir error y agregar pie de página",
      summary: "Corrija el error y agregue un pie de página.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-110": {
      title: "Separe AdminAuthFilter y ActuatorFilter",
      summary: "AdminAuthFilter y ActuatorFilter separados y reforzados.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, administración y documentos relacionados para esta versión."
      ]
    },
    "pr-109": {
      title: "Monitoreo de Prometeo",
      summary: "Monitoreo de Prometheus actualizado.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, administración, interfaz de usuario, infraestructura y documentos relacionados para esta versión."
      ]
    },
    "pr-108": {
      title: "Menú más grande para móviles",
      summary: "Menú más grande para dispositivos móviles mejorado.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-107": {
      title: "Mejora del diseño de la interfaz de usuario del menú",
      summary: "Mejora de la interfaz de usuario del diseño del menú.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, administración, archivos adjuntos y UI relacionados para esta versión."
      ]
    },
    "pr-106": {
      title: "Actualización del certificado SSL",
      summary: "Actualización de certificado SSL reforzado.",
      changes: [
        "Se actualizaron las rutas de código de seguridad, calendario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-105": {
      title: "Excluir /.well-known de la redirección HTTPS",
      summary: "Se ha reforzado la exclusión de /.well-known de la redirección HTTPS.",
      changes: [
        "Se actualizaron las rutas del código de seguridad relacionadas para esta versión."
      ]
    },
    "pr-104": {
      title: "Utilice el submódulo secreto para archivos secretos en lugar de datos base64",
      summary: "Se actualizó el uso del submódulo secreto para archivos secretos en lugar de datos base64.",
      changes: [
        "Se actualizaron los archivos adjuntos relacionados y las rutas de código de infraestructura para esta versión."
      ]
    },
    "pr-103": {
      title: "El intervalo mínimo de notificación de holgura se configura mediante propiedades...",
      summary: "El intervalo mínimo de notificación de holgura agregado se configura mediante propiedades….",
      changes: [
        "Se actualizaron las rutas del código de notificaciones relacionadas para esta versión."
      ]
    },
    "pr-102": {
      title: "JWT Interceptor -> filtro refactorizado",
      summary: "Interceptor jWT endurecido -> filtro refactorizado.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, programación, administración, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-100": {
      title: "Función de cambio de orden de posición programada",
      summary: "Función mejorada de cambio de orden de posición del cronograma.",
      changes: [
        "Se actualizaron las rutas de código relacionadas con Schedule, Infra y Docs para esta versión."
      ]
    },
    "pr-99": {
      title: "Eliminar página de edición de tareas. ¡Hurra!",
      summary: "Duty.html lo maneja de forma asíncrona.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-98": {
      title: "Pequeña mejora de diseño, mejora de UX, corrección de errores",
      summary: "Error de comparación de fechas solucionado.",
      changes: [
        "Error de las 12:00 p.m. solucionado.",
        "Puede actualizar el color APAGADO del departamento.",
        "Puede asignar gerente de departamento [nulo]."
      ]
    },
    "pr-97": {
      title: "Corrige algunos errores menores y estilo.",
      summary: "Se corrigieron algunos errores menores y estilo.",
      changes: [
        "Se actualizaron las rutas de código de UI, Administrador y Notificaciones relacionadas para esta versión."
      ]
    },
    "pr-95": {
      title: "El mensaje flojo solo se envía como máximo una vez cada diez segundos",
      summary: "Se corrigió que el mensaje de holgura solo se enviaba como máximo una vez cada diez segundos.",
      changes: [
        "Se actualizó la programación relacionada y las rutas del código de notificaciones para esta versión."
      ]
    },
    "pr-94": {
      title: "Característica: Horario",
      summary: "Debe ejecutar SQL para migrar la nota -> programar.",
      changes: [
        "La columna de notas podría eliminarse.",
        "``sql INSERT INTO program (id, member_id, content, start_date_time, end_date_time, position) SELECT UUID(), d.member_id, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(d.memo, '\\n', number.n), '\\n', -1)), TIMESTAMP(CONCAT_WS('-', d.duty_year, d.duty_month, d.duty_day)), TIMESTAMP(CONCAT_WS('-', d.duty_year, d.duty_month, d.duty_day)), números.n."
      ]
    },
    "pr-93": {
      title: "Validación de cookies del token de actualización de diapositivas",
      summary: "La validación se extendía cuando el inicio de sesión era exitoso, pero la cookie simbólica no, lo que significa \"sin sentido\", por lo que la actualicé.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad y calendario relacionadas para esta versión."
      ]
    },
    "pr-91": {
      title: "Se agregó la calculadora del día D",
      summary: "Entonces, si selecciona el evento del Día D, mostrará el conteo en el cierre #90 del calendario actual.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-89": {
      title: "Ordenar miembros en la página de índice",
      summary: "Miembros de orden fijo en la página de índice.",
      changes: [
        "Se actualizaron las rutas del código de mantenimiento relacionadas para esta versión."
      ]
    },
    "pr-88": {
      title: "Modal más grande para la búsqueda de miembros en el administrador",
      summary: "Se corrigió un modal más grande para la búsqueda de miembros en el administrador.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, administrador y equipo relacionadas para esta versión."
      ]
    },
    "pr-87": {
      title: "Sistema de gestión de departamentos",
      summary: "Añadido sistema de gestión de departamentos.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, equipo, administrador y calendario relacionadas para esta versión."
      ]
    },
    "pr-86": {
      title: "Editar nota de página UX mejorada",
      summary: "La línea previa de notas ahora también está trabajando en la edición.",
      changes: [
        "La página de edición tiene etiquetas de tipo de servicio.",
        "Botones más pequeños para cambiar el tipo de servicio."
      ]
    },
    "pr-84": {
      title: "Gestión del departamento administrativo.",
      summary: "Gestión mejorada del departamento de administración.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, equipo, administración, panel y UI relacionados para esta versión."
      ]
    },
    "pr-82": {
      title: "Favicon para todos los entornos",
      summary: "Favicon actualizado para todos los entornos.",
      changes: [
        "Se actualizaron las rutas de código de amigos, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-81": {
      title: "El icono táctil de Apple se convierte en un camino absoluto.",
      summary: "Se corrigió que el ícono táctil de Apple se convirtiera en una ruta absoluta.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-118": {
      title: "Se agregó el cargador waitMe para llamadas CURD del Día D en la aplicación Vue",
      summary: "Se agregó el cargador waitMe para llamadas CURD del Día D en la aplicación Vue.",
      changes: [
        "Se actualizaron las rutas del código de mantenimiento relacionadas para esta versión."
      ]
    },
    "pr-78": {
      title: "CI/CD y actualizaciones menores",
      summary: "Legibilidad mejorada para \"hoy\", SÁB, DOM.",
      changes: [
        "Seguimiento de pila P6spy habilitado.",
        "Se agregó trabajo de CI/CD."
      ]
    },
    "pr-72": {
      title: "Revocar tokens de actualización caducados",
      summary: "También se renueva el certificado ssl.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, administración e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-71": {
      title: "Códigos de prueba refactorizados",
      summary: "Utilice la clase datainit para que no sea necesario iniciarlo en cada prueba.",
      changes: [
        "Utilice {'@'}Transactional positivamente para las pruebas de reversión."
      ]
    },
    "pr-70": {
      title: "Mejora de mi página de administración de inicio de sesión",
      summary: "Ordenar por último activo.",
      changes: [
        "La última pantalla activa cambió (a partir de ahora usando day.js).",
        "Jwt valida el segundo 3600 -> 1800."
      ]
    },
    "pr-68": {
      title: "Mi gestión de inicio de sesión",
      summary: "Agregué mi gestión de inicio de sesión.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad y UI relacionadas para esta versión."
      ]
    },
    "pr-67": {
      title: "Página de administración agregada",
      summary: "Problema de P6spy boot3.0 resuelto.",
      changes: [
        "Toda la página de monitoreo de información de inicio de sesión activa."
      ]
    },
    "pr-65": {
      title: "Página de administración sencilla",
      summary: "Página de administración simple para verificar la información del token de actualización.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad y administración relacionadas para esta versión."
      ]
    },
    "pr-64": {
      title: "Actualizar información remota de registros de tokens",
      summary: "El token de actualización reforzado registra información remota.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-63": {
      title: "D + días calcular arreglo",
      summary: "El día después del Día D debería ser el Día 2 (D+2).",
      changes: [
        "Se actualizaron las rutas del código de mantenimiento relacionadas para esta versión."
      ]
    },
    "pr-62": {
      title: "Mejora de la experiencia de usuario del día D",
      summary: "Notificación de holgura de actualización de DDay.",
      changes: [
        "Espérame cuando reorganices los pedidos del día.",
        "Edición del día D -> mejor experiencia."
      ]
    },
    "pr-57": {
      title: "El cálculo del día D no fue correcto",
      summary: "Ahora se calcula desde el servidor.",
      changes: [
        "Se actualizaron las rutas del código de mantenimiento relacionadas para esta versión."
      ]
    },
    "pr-56": {
      title: "Contador del día D",
      summary: "RESTAPI y también ver la página del contador del Día D.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad y UI relacionadas para esta versión."
      ]
    },
    "pr-53": {
      title: "Página de edición de tareas desactivada + error de color de nota solucionado",
      summary: "Si hay una nota en un día libre, el color de fondo no se presentó correctamente.",
      changes: [
        "Ahora está bien."
      ]
    },
    "pr-52": {
      title: "Estilo",
      summary: "Centro indicador de mes.",
      changes: [
        "Problema con iOS Safari."
      ]
    },
    "pr-49": {
      title: "Resalte hoy en la página de edición, obtenga una vista previa de la corrección de errores de los bloques del próximo mes",
      summary: "Se corrigió el resaltado hoy en la página de edición, la vista previa del próximo mes bloquea la corrección de errores.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-45": {
      title: "Explorador de calendario",
      summary: "#41.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-44": {
      title: "Explorador de calendario",
      summary: "Explorador de calendario mejorado.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, archivos adjuntos y UI relacionados para esta versión."
      ]
    },
    "pr-43": {
      title: "Editar, texto del botón Atrás editado",
      summary: "Edición actualizada, texto del botón Atrás editado.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-42": {
      title: "Página de inicio de sesión: interfaz de usuario móvil",
      summary: "Interfaz de usuario web responsiva.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, archivos adjuntos y UI relacionados para esta versión."
      ]
    },
    "pr-39": {
      title: "Autenticación",
      summary: "Autenticación reforzada.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, calendario, equipo, notificaciones y UI relacionadas para esta versión."
      ]
    },
    "pr-35": {
      title: "Migración de Spring Boot 2.7.4 -> 3.0.0",
      summary: "Migración mejorada de Spring Boot 2.7.4 -> 3.0.0.",
      changes: [
        "Se actualizaron las rutas relacionadas con el equipo, las notificaciones, la interfaz de usuario y el código de infraestructura para esta versión."
      ]
    },
    "pr-33": {
      title: "Codificador de contraseña cambiado, csrf deshabilitado",
      summary: "Contraseña reforzada Codificador cambiado, csrf deshabilitado.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-32": {
      title: "HTTPS SSL seguro",
      summary: "hTTPS SSL reforzado.",
      changes: [
        "Se actualizaron las rutas de código de seguridad, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-31": {
      title: "Optimización de lectura y actualización",
      summary: "Latencia de actualización mejorada: 600 ms -> 100 ms.",
      changes: [
        "Se actualizaron las rutas relacionadas con el calendario, el equipo, las notificaciones, la interfaz de usuario y el código de infraestructura para esta versión."
      ]
    },
    "pr-30": {
      title: "Las solicitudes que no tienen dirección de dominio se ignoran",
      summary: "Debido a demasiadas solicitudes aleatorias.",
      changes: [
        "Se actualizaron las rutas del código de mantenimiento relacionadas para esta versión."
      ]
    },
    "pr-26": {
      title: "Enviar notificación de holgura asíncrona",
      summary: "Envío mejorado de notificación de holgura asíncrona.",
      changes: [
        "Se actualizaron las rutas del código de notificaciones relacionadas para esta versión."
      ]
    },
    "pr-24": {
      title: "Ingrese la contraseña cuando vaya a editar la página n.° 10",
      summary: "#10.",
      changes: [
        "Se actualizaron las rutas de código de autenticación, seguridad y UI relacionadas para esta versión."
      ]
    },
    "pr-21": {
      title: "Mejora de UX de la página de edición de tareas",
      summary: "Mejora de la experiencia de usuario de la página de edición de tareas mejorada.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-19": {
      title: "Método de manejo no admitido Excepción",
      summary: "Método de control fijo no admitido Excepción.",
      changes: [
        "Se actualizaron las rutas del código de notificaciones relacionadas para esta versión."
      ]
    },
    "pr-17": {
      title: "Flecha agregada para la página de edición.",
      summary: "Se eliminó el código repetido.",
      changes: [
        "Barra de desplazamiento oculta que era irritante.",
        "También se agregó una flecha para editar la página de tareas."
      ]
    },
    "pr-15": {
      title: "Webhook de Slack para excepciones",
      summary: "Se corrigió el webhook flojo para excepciones.",
      changes: [
        "Se actualizaron las rutas relacionadas con el calendario, las notificaciones, la interfaz de usuario y el código de infraestructura para esta versión."
      ]
    },
    "pr-13": {
      title: "Diseño web responsivo para móviles",
      summary: "Interfaz de usuario móvil.",
      changes: [
        "Se actualizaron las rutas de código de UI relacionadas para esta versión."
      ]
    },
    "pr-11": {
      title: "UI de edición de tareas mejorada",
      summary: "Se mejoró la interfaz de usuario del botón de cambio de tareas.",
      changes: [
        "Se mejoró la interfaz de usuario de cambio de notas."
      ]
    },
    "pr-111": {
      title: "Mejorar la claridad de la interfaz de usuario para el proceso de creación de horarios",
      summary: "Mejore la claridad de la interfaz de usuario para el proceso de creación de horarios.",
      changes: [
        "Se actualizaron las rutas de código de programación, administración, interfaz de usuario e infraestructura relacionadas para esta versión."
      ]
    },
    "pr-113": {
      title: "Mejorar la claridad de la interfaz de usuario para dispositivos móviles",
      summary: "Mejore la claridad de la interfaz de usuario para dispositivos móviles.",
      changes: [
        "Se actualizaron las rutas de código de interfaz de usuario, administrador y equipo relacionadas para esta versión."
      ]
    },
    "pr-7": {
      title: "Función de notas mejorada",
      summary: "Se admiten notas de varias líneas.",
      changes: [
        "La nota original se mostrará cuando la edites.",
        "Se mejoró la legibilidad del deber."
      ]
    },
    "pr-80": {
      title: "Actualizar favicon",
      summary: "Actualizar favicon.",
      changes: [
        "Se actualizaron las rutas de código de infraestructura, interfaz de usuario y calendario relacionadas para esta versión."
      ]
    },
    "pr-8": {
      title: "Botón de inicio agregado",
      summary: "Botón de inicio agregado.",
      changes: [
        "Se actualizó el panel relacionado y las rutas de código de la interfaz de usuario para esta versión."
      ]
    }
  }
} satisfies ReleaseNotesMessages<ReleaseNoteId>
