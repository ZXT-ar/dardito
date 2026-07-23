import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/story.dart';

abstract interface class StoryRepository {
  List<CityStory> getAll();
}

class LocalStoryRepository implements StoryRepository {
  static const categories = [
    StoryCategory(
      'architecture',
      'Arquitectura',
      Icons.architecture_rounded,
      AppColors.rust,
    ),
    StoryCategory(
      'mystery',
      'Misterios',
      Icons.auto_awesome_rounded,
      Color(0xFF5E537B),
    ),
    StoryCategory(
      'culture',
      'Cultura',
      Icons.theater_comedy_rounded,
      Color(0xFF9A6B24),
    ),
    StoryCategory(
      'neighborhood',
      'Barrios',
      Icons.holiday_village_rounded,
      AppColors.green,
    ),
    StoryCategory(
      'memory',
      'Memoria viva',
      Icons.photo_camera_back_rounded,
      Color(0xFF416A76),
    ),
  ];

  @override
  List<CityStory> getAll() => const [
    CityStory(
      id: 'diagonales',
      title: 'La ciudad que nació de un plano',
      subtitle: 'El diseño que todavía guía nuestros pasos',
      category: StoryCategory(
        'architecture',
        'Arquitectura',
        Icons.architecture_rounded,
        AppColors.rust,
      ),
      neighborhood: 'Casco Urbano',
      period: '1882',
      mapX: .50,
      mapY: .49,
      latitude: -34.9214,
      longitude: -57.9544,
      featured: true,
      readMinutes: 5,
      evidence: EvidenceLevel.documented,
      source: 'Archivo Histórico de la Provincia de Buenos Aires',
      shortStory:
          'La Plata fue pensada antes de ser caminada: una cuadrícula atravesada por diagonales, plazas y un bosque que hizo del plano una identidad.',
      fullStory:
          'La fundación de La Plata en 1882 estuvo acompañada por una planificación urbana excepcional para su tiempo. El trazado atribuido al equipo de Pedro Benoit organizó una cuadrícula regular, cruzada por diagonales y plazas distribuidas con una lógica precisa. Más que una rareza geométrica, el plano buscaba ventilación, circulación y espacios verdes. Esa estructura sigue orientando —y a veces desorientando— a quienes caminan la ciudad. Mirarla desde arriba permite entender por qué la forma urbana se volvió uno de los símbolos platenses más reconocibles.',
    ),
    CityStory(
      id: 'catedral',
      title: 'Una catedral que esperó sus torres',
      subtitle: 'Más de un siglo para completar el horizonte',
      category: StoryCategory(
        'architecture',
        'Arquitectura',
        Icons.architecture_rounded,
        AppColors.rust,
      ),
      neighborhood: 'Plaza Moreno',
      period: '1884–1999',
      mapX: .50,
      mapY: .57,
      latitude: -34.9229,
      longitude: -57.9560,
      featured: true,
      readMinutes: 4,
      evidence: EvidenceLevel.documented,
      source: 'Museo de la Catedral de La Plata',
      shortStory:
          'La piedra fundamental se colocó en 1884, pero la silueta que hoy reconocemos terminó de definirse más de cien años después.',
      fullStory:
          'La Catedral de la Inmaculada Concepción comenzó a construirse poco después de la fundación de la ciudad. Durante décadas su fachada permaneció sin las torres proyectadas. Recién hacia fines del siglo XX una gran obra de restauración y completamiento permitió levantar las agujas que hoy recortan el cielo de Plaza Moreno. La larga espera convirtió al edificio en testigo de varias generaciones y en una buena manera de leer cómo una ciudad también termina de imaginarse con el tiempo.',
    ),
    CityStory(
      id: 'tuneles',
      title: 'Los túneles bajo la ciudad',
      subtitle: 'Entre planos, pasadizos y versiones',
      category: StoryCategory(
        'mystery',
        'Misterios',
        Icons.auto_awesome_rounded,
        Color(0xFF5E537B),
      ),
      neighborhood: 'Centro',
      period: 'Finales del siglo XIX',
      mapX: .44,
      mapY: .44,
      latitude: -34.9186,
      longitude: -57.9464,
      featured: true,
      readMinutes: 6,
      evidence: EvidenceLevel.oralTradition,
      source:
          'Relatos urbanos y registros periodísticos; versiones en revisión',
      shortStory:
          'Bajo edificios públicos aparecen subsuelos y pasajes reales. La leyenda los conecta en una red secreta mucho más extensa.',
      fullStory:
          'La idea de una red de túneles que une los principales edificios públicos es una de las leyendas más persistentes de La Plata. Existen subsuelos, conductos técnicos y pasajes documentados en distintos puntos, pero no todas las conexiones que circulan en relatos populares han sido comprobadas. Dardito conserva las dos capas: aquello que puede verificarse y las versiones que la ciudad siguió contando. El misterio, en este caso, también revela cómo imaginamos el subsuelo de una capital planificada.',
    ),
    CityStory(
      id: 'republica',
      title: 'La república donde gobiernan los chicos',
      subtitle: 'Una ciudad en miniatura dentro del bosque',
      category: StoryCategory(
        'culture',
        'Cultura',
        Icons.theater_comedy_rounded,
        Color(0xFF9A6B24),
      ),
      neighborhood: 'Gonnet',
      period: '1951',
      mapX: .25,
      mapY: .23,
      latitude: -34.8905,
      longitude: -58.0184,
      featured: true,
      readMinutes: 4,
      evidence: EvidenceLevel.documented,
      source: 'Archivo de la República de los Niños',
      shortStory:
          'En Gonnet existe una pequeña ciudad cívica creada para que las infancias aprendan ciudadanía jugando.',
      fullStory:
          'La República de los Niños abrió sus puertas en 1951 como un espacio educativo y recreativo a escala infantil. Sus edificios representan instituciones de una república democrática y mezclan referencias arquitectónicas de distintos lugares del mundo. Generaciones enteras la visitaron en excursiones, paseos familiares y jornadas escolares. Más allá de las historias que rodean su origen, su valor reside en una idea singular: aprender cómo funciona una comunidad recorriéndola con el cuerpo y la imaginación.',
    ),
    CityStory(
      id: 'meridiano',
      title: 'Cuando Meridiano V volvió a encontrarse',
      subtitle: 'La estación que se convirtió en barrio cultural',
      category: StoryCategory(
        'neighborhood',
        'Barrios',
        Icons.holiday_village_rounded,
        AppColors.green,
      ),
      neighborhood: 'Meridiano V',
      period: '1910–actualidad',
      mapX: .57,
      mapY: .75,
      latitude: -34.9318,
      longitude: -57.9392,
      readMinutes: 5,
      evidence: EvidenceLevel.documented,
      source: 'Archivo ferroviario y organizaciones culturales barriales',
      shortStory:
          'Donde dejaron de llegar trenes, vecinos y artistas construyeron un nuevo punto de encuentro.',
      fullStory:
          'La estación Provincial fue una pieza central del ferrocarril y dio identidad a la zona. Tras el cierre de servicios, el edificio y sus alrededores atravesaron años de silencio. La recuperación comunitaria impulsó talleres, espectáculos, gastronomía y encuentros culturales. Meridiano V muestra que el patrimonio no queda quieto: puede adquirir una vida nueva cuando un barrio decide volver a habitarlo.',
    ),
    CityStory(
      id: 'tolosa',
      title: 'La memoria ferroviaria de Tolosa',
      subtitle: 'Talleres, familias y un barrio hecho alrededor del tren',
      category: StoryCategory(
        'memory',
        'Memoria viva',
        Icons.photo_camera_back_rounded,
        Color(0xFF416A76),
      ),
      neighborhood: 'Tolosa',
      period: '1880–actualidad',
      mapX: .34,
      mapY: .36,
      latitude: -34.9023,
      longitude: -57.9690,
      readMinutes: 4,
      evidence: EvidenceLevel.community,
      source: 'Aporte de vecinos — pendiente de revisión editorial',
      shortStory:
          'Los talleres no fueron solo un lugar de trabajo: organizaron rutinas, afectos y relatos que todavía circulan entre familias.',
      fullStory:
          'En Tolosa, la historia ferroviaria aparece en fotografías familiares, oficios transmitidos y recuerdos cotidianos. Este relato reúne un primer aporte comunitario sobre las jornadas de los talleres y las redes vecinales que crecieron alrededor. Está señalado como memoria viva porque necesita ampliar testimonios y fuentes antes de considerarse documentado. Su lugar en el mapa recuerda que una ciudad también se conoce escuchando a quienes la vivieron.',
    ),
    CityStory(
      id: 'bosque',
      title: 'El bosque antes de la ciudad',
      subtitle: 'Un paisaje que cambió de sentido',
      category: StoryCategory(
        'memory',
        'Memoria viva',
        Icons.photo_camera_back_rounded,
        Color(0xFF416A76),
      ),
      neighborhood: 'El Bosque',
      period: 'Siglo XIX',
      mapX: .61,
      mapY: .25,
      latitude: -34.9085,
      longitude: -57.9370,
      readMinutes: 3,
      evidence: EvidenceLevel.documented,
      source: 'Museo y Archivo Dardo Rocha',
      shortStory:
          'Antes del paseo, los museos y las canchas, estas tierras formaban parte de otra geografía productiva.',
      fullStory:
          'El Paseo del Bosque ocupa tierras que anteceden a la fundación de La Plata. Con la nueva capital, el área fue transformándose en uno de sus grandes espacios públicos y científicos: allí se instalaron el Museo, el Observatorio, el Jardín Zoológico y luego instituciones deportivas. Sus senderos reúnen capas muy distintas de la ciudad, desde la planificación fundacional hasta las experiencias cotidianas de estudiantes, familias e hinchas.',
    ),
    CityStory(
      id: 'citybell',
      title: 'La campana que nombró a City Bell',
      subtitle: 'Una identidad nacida junto a las vías',
      category: StoryCategory(
        'neighborhood',
        'Barrios',
        Icons.holiday_village_rounded,
        AppColors.green,
      ),
      neighborhood: 'City Bell',
      period: '1914',
      mapX: .14,
      mapY: .14,
      latitude: -34.8650,
      longitude: -58.0470,
      readMinutes: 3,
      evidence: EvidenceLevel.documented,
      source: 'Reseñas históricas municipales',
      shortStory:
          'El crecimiento alrededor de la estación convirtió un nombre ferroviario en una identidad barrial propia.',
      fullStory:
          'City Bell se consolidó alrededor del ferrocarril y de loteos que atrajeron a nuevas familias. Su nombre se asocia a la familia Bell, vinculada a las tierras de la zona. Con el tiempo, calles arboladas, comercios y espacios de encuentro construyeron una identidad que excede el origen ferroviario. La historia local se sigue completando con recuerdos de antiguos vecinos y archivos familiares.',
    ),
  ];
}
